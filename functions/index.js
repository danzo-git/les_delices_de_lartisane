const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const axios = require('axios');
const crypto = require('crypto');

initializeApp();

const geniusPayPublicKey = defineSecret('GENIUS_PAY_PUBLIC_KEY');
const geniusPaySecretKey = defineSecret('GENIUS_PAY_SECRET_KEY');
const geniusPayWebhookSecret = defineSecret('GENIUS_PAY_WEBHOOK_SECRET');

const GENIUS_PAY_API_URL = 'https://geniuspay.ci/api/v1/merchant/payments';

exports.createPayment = onCall(
    { secrets: [geniusPayPublicKey, geniusPaySecretKey] },
    async (request) => {
        // 1. Vérifier l'authentification
        if (!request.auth) {
            throw new HttpsError('unauthenticated', 'Utilisateur non connecté.');
        }

        const orderId = request.data.orderId;
        if (!orderId) {
            throw new HttpsError('invalid-argument', 'orderId est requis.');
        }

        const db = getFirestore();

        try {
            // 2. Récupérer la commande
            const orderSnapshot = await db.collection('orders').doc(orderId).get();
            if (!orderSnapshot.exists) {
                throw new HttpsError('not-found', 'Commande introuvable.');
            }

            const orderData = orderSnapshot.data();

            // Vérifier le montant minimum (200 XOF)
            const amount = Number(orderData.total);
            if (!amount || amount < 200) {
                throw new HttpsError('invalid-argument', `Montant invalide: ${amount}. Minimum 200 XOF.`);
            }

            // 3. Appel à GeniusPay
            const payload = {
                amount: amount,
                description: `Commande #${orderData.numero}`,
                customer: {
                    name: orderData.client_nom,
                    phone: orderData.client_telephone
                },
                metadata: {
                    order_id: orderId
                }
            };

            console.log('Appel GeniusPay avec payload:', JSON.stringify(payload));

            const response = await axios.post(GENIUS_PAY_API_URL, payload, {
                headers: {
                    'X-API-Key': geniusPayPublicKey.value(),
                    'X-API-Secret': geniusPaySecretKey.value(),
                    'Content-Type': 'application/json'
                }
            });

            console.log('Réponse GeniusPay:', response.status, JSON.stringify(response.data));

            // 4. Retourner l'URL de checkout (GeniusPay enveloppe dans { success, data: { checkout_url } })
            const responseBody = response.data;
            const checkoutUrl = responseBody?.data?.checkout_url;

            if (checkoutUrl) {
                return { checkout_url: checkoutUrl };
            } else {
                throw new Error(`checkout_url manquant. Réponse: ${JSON.stringify(responseBody)}`);
            }

        } catch (error) {
            if (error instanceof HttpsError) throw error;

            // Extraire le détail de l'erreur axios
            if (error.response) {
                const status = error.response.status;
                const body = JSON.stringify(error.response.data);
                console.error(`Erreur GeniusPay HTTP ${status}: ${body}`);
                throw new HttpsError('internal', `GeniusPay a retourné une erreur HTTP ${status}: ${body}`);
            }

            console.error('Erreur lors de la création du paiement GeniusPay:', error.message, error.stack);
            throw new HttpsError('internal', `Impossible d'initier le paiement: ${error.message}`);
        }
    }
);

exports.geniusPayWebhook = onRequest(
    { secrets: [geniusPayWebhookSecret] },
    async (req, res) => {
        const db = getFirestore();

        try {
            const signature = req.headers['x-webhook-signature'];

            if (!req.rawBody) {
                return res.status(400).send('rawBody manquant');
            }
            const payloadString = req.rawBody.toString('utf8');

            // TEMPORAIRE : logger rawBody exact + signature reçue pour debug
            console.log("RAW_BODY_EXACT:", payloadString);
            console.log("SIGNATURE_RECUE:", req.headers['x-webhook-signature']);
            console.log("HEADERS:", JSON.stringify(req.headers));

            // Log temporaire pour vérifier l'état du secret webhook
            const secretValue = geniusPayWebhookSecret.value();
            console.log("Secret Webhook chargé :", !!secretValue, "longueur :", secretValue?.length);

            // Le timestamp vient du HEADER X-Webhook-Timestamp (confirmé doc officielle)
            const timestamp = req.headers['x-webhook-timestamp'];

            // Log brut du payload pour inspection (Temporaire)
            console.log("PAYLOAD BRUT GENIUSPAY:", JSON.stringify(req.body));

            if (!timestamp) {
                return res.status(400).send('timestamp manquant dans le payload');
            }

            // Validation de la signature HMAC
            if (!signature) {
                return res.status(401).send('Signature manquante');
            }

            const stringToSign = `${timestamp}.${payloadString}`;
            const expectedSignature = crypto
                .createHmac('sha256', secretValue)
                .update(stringToSign)
                .digest('hex');

            // Log détaillé pour la signature
            console.log("Calcul Signature:", {
                attendue: expectedSignature,
                recue: signature,
                timestamp: timestamp,
                rawStart: payloadString.substring(0, 50)
            });

            const sigBuffer = Buffer.from(signature, 'hex');
            const expBuffer = Buffer.from(expectedSignature, 'hex');

            if (sigBuffer.length !== expBuffer.length || !crypto.timingSafeEqual(sigBuffer, expBuffer)) {
                console.warn('Signature invalide', { signature, expectedSignature });
                return res.status(401).send('Signature invalide');
            }

            const body = req.body;
            // GeniusPay enveloppe les données dans body.data
            const paymentData = body.data;
            const orderId = paymentData?.metadata?.order_id;
            const eventType = body.event;

            if (!orderId) {
                console.error('order_id manquant. Structure body:', JSON.stringify(body));
                return res.status(400).send('order_id manquant');
            }

            const orderRef = db.collection('orders').doc(orderId);
            const orderSnapshot = await orderRef.get();

            if (!orderSnapshot.exists) {
                return res.status(404).send('Commande non trouvée');
            }

            let newPaymentStatus = 'en_attente';
            let newOrderStatus = orderSnapshot.data().statut_commande;

            if (eventType === 'payment.success') {
                newPaymentStatus = 'confirme';
                newOrderStatus = 'en_preparation';
            } else if (['payment.failed', 'payment.cancelled', 'payment.expired'].includes(eventType)) {
                newPaymentStatus = 'echoue';
            }

            const historyEntry = {
                statut: eventType === 'payment.success' ? 'paiement_confirme' : 'paiement_echoue',
                date: Timestamp.now()
            };

            await orderRef.update({
                statut_paiement: newPaymentStatus,
                statut_commande: newOrderStatus,
                historique_statuts: FieldValue.arrayUnion(historyEntry)
            });

            console.log(`Commande ${orderId} mise à jour: paiement=${newPaymentStatus}, commande=${newOrderStatus}`);
            res.status(200).send('Webhook traité avec succès');
        } catch (error) {
            console.error('Erreur webhook:', error.message);
            res.status(500).send('Erreur interne du serveur');
        }
    }
);

// -----------------------------------------------------------------------------
// NOTIFICATIONS PUSH
// -----------------------------------------------------------------------------
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const DELIVERY_SETTINGS_PATH = 'delivery_settings/default';
const DELIVERY_TIME_ZONE = 'Africa/Abidjan';

function parseDeliveryDateKey(value) {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
        return null;
    }
    const [year, month, day] = value.split('-').map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));
    if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
        return null;
    }
    return { year, month, day, date };
}

function deliverySlotsForDate(settings, dateKey, now = Date.now()) {
    const parsedDate = parseDeliveryDateKey(dateKey);
    if (!parsedDate) {
        throw new HttpsError('invalid-argument', 'Date de créneau invalide.');
    }

    const weekday = parsedDate.date.getUTCDay() || 7;
    const today = new Date(now);
    const todayKey = `${today.getUTCFullYear()}-${String(today.getUTCMonth() + 1).padStart(2, '0')}-${String(today.getUTCDate()).padStart(2, '0')}`;
    const todayDate = parseDeliveryDateKey(todayKey).date;
    const daysAhead = Math.round((parsedDate.date.getTime() - todayDate.getTime()) / 86400000);
    const maximumDaysAhead = Number(settings.maximum_days_ahead) || 90;
    const minimumNoticeHours = Math.max(0, Number(settings.minimum_notice_hours) || 0);
    const minimumStart = now + minimumNoticeHours * 60 * 60 * 1000;

    if (daysAhead < 0 || daysAhead > maximumDaysAhead) return [];
    if ((settings.closed_dates || []).includes(dateKey)) return [];

    return (settings.slots || [])
        .filter((slot) => slot.active !== false && Number(slot.weekday) === weekday)
        .map((slot) => {
            const startMinute = Number(slot.start_minute);
            const endMinute = Number(slot.end_minute);
            const capacity = Number(slot.capacity);
            if (!Number.isInteger(startMinute) || !Number.isInteger(endMinute) ||
                endMinute <= startMinute || !Number.isInteger(capacity) || capacity < 1) {
                return null;
            }
            const startMillis = Date.UTC(parsedDate.year, parsedDate.month - 1, parsedDate.day,
                Math.floor(startMinute / 60), startMinute % 60);
            const endMillis = Date.UTC(parsedDate.year, parsedDate.month - 1, parsedDate.day,
                Math.floor(endMinute / 60), endMinute % 60);
            if (startMillis < minimumStart) return null;

            return {
                id: String(slot.id),
                date: dateKey,
                weekday,
                start_minute: startMinute,
                end_minute: endMinute,
                capacity,
                start_millis: startMillis,
                end_millis: endMillis,
                time_label: `${String(Math.floor(startMinute / 60)).padStart(2, '0')}:${String(startMinute % 60).padStart(2, '0')} – ${String(Math.floor(endMinute / 60)).padStart(2, '0')}:${String(endMinute % 60).padStart(2, '0')}`,
            };
        })
        .filter(Boolean)
        .sort((a, b) => a.start_minute - b.start_minute);
}

function deliveryUsageId(dateKey, slotId) {
    return `${dateKey}_${slotId}`;
}

exports.getAvailableDeliverySlots = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Connecte-toi pour consulter les créneaux.');
    }

    const db = getFirestore();
    const settingsSnapshot = await db.doc(DELIVERY_SETTINGS_PATH).get();
    const settings = settingsSnapshot.exists ? settingsSnapshot.data() : { enabled: false };
    if (!settings.enabled) return { enabled: false, slots: [] };

    const slots = deliverySlotsForDate(settings, request.data?.date);
    const withAvailability = await Promise.all(slots.map(async (slot) => {
        const usageSnapshot = await db.collection('delivery_slot_usage')
            .doc(deliveryUsageId(slot.date, slot.id)).get();
        const reserved = usageSnapshot.exists ? Number(usageSnapshot.data().reserved_count) || 0 : 0;
        const remaining = Math.max(0, slot.capacity - reserved);
        if (remaining < 1) return null;
        return {
            id: slot.id,
            date: slot.date,
            time_label: slot.time_label,
            start_at: new Date(slot.start_millis).toISOString(),
            end_at: new Date(slot.end_millis).toISOString(),
            remaining_capacity: remaining,
        };
    }));

    return { enabled: true, slots: withAvailability.filter(Boolean) };
});

exports.createOrderWithSlot = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Connecte-toi avant de commander.');
    }

    const db = getFirestore();
    const input = request.data?.order;
    const orderId = request.data?.order_id;
    if (!input || typeof input !== 'object' || !Array.isArray(input.items) || input.items.length < 1 || input.items.length > 30) {
        throw new HttpsError('invalid-argument', 'Le panier de la commande est invalide.');
    }
    if (typeof orderId !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(orderId)) {
        throw new HttpsError('invalid-argument', 'Identifiant de commande invalide.');
    }

    const itemProductRefs = input.items.map((item) => {
        if (!item || typeof item.product_id !== 'string' || !item.product_id ||
            typeof item.option_label !== 'string' || !item.option_label ||
            !Number.isInteger(Number(item.quantite)) || Number(item.quantite) < 1 || Number(item.quantite) > 99) {
            throw new HttpsError('invalid-argument', 'Un article du panier est invalide.');
        }
        return db.collection('products').doc(item.product_id);
    });

    const [productSnapshots, profileSnapshot, feeSnapshots] = await Promise.all([
        db.getAll(...itemProductRefs),
        db.collection('users').doc(request.auth.uid).get(),
        db.collection('delivery_fees').get(),
    ]);

    const orderItems = input.items.map((item, index) => {
        const productSnapshot = productSnapshots[index];
        if (!productSnapshot.exists) {
            throw new HttpsError('failed-precondition', 'Un produit de la commande n’est plus disponible.');
        }
        const product = productSnapshot.data();
        if (product.disponible === false) {
            throw new HttpsError('failed-precondition', `Le produit « ${product.nom || ''} » n’est plus disponible.`);
        }
        const option = (product.options || []).find((candidate) => candidate.label === item.option_label);
        const price = Number(option?.prix);
        if (!option || !Number.isFinite(price) || price < 0) {
            throw new HttpsError('failed-precondition', 'Une option de produit a changé. Vérifie ton panier.');
        }
        const quantity = Number(item.quantite);
        return {
            product_id: productSnapshot.id,
            nom: product.nom || item.nom || 'Produit',
            option_label: option.label,
            prix_unitaire: price,
            quantite: quantity,
            sous_total: price * quantity,
        };
    });

    const modeLivraison = input.mode_livraison;
    if (!['retrait', 'livraison'].includes(modeLivraison)) {
        throw new HttpsError('invalid-argument', 'Mode de retrait invalide.');
    }

    let deliveryFee = 0;
    if (modeLivraison === 'livraison') {
        const commune = String(input.commune || '').trim();
        const address = String(input.adresse_livraison || '').trim();
        if (!commune || !address) {
            throw new HttpsError('invalid-argument', 'La commune et l’adresse de livraison sont obligatoires.');
        }
        const feeSnapshot = feeSnapshots.docs.find((doc) => {
            const fee = doc.data();
            return fee.actif === true && String(fee.commune || fee.nom || doc.id) === commune;
        });
        if (!feeSnapshot) {
            throw new HttpsError('failed-precondition', 'La commune sélectionnée n’est pas desservie.');
        }
        deliveryFee = Number(feeSnapshot.data().frais) || 0;
    }

    const subtotal = orderItems.reduce((sum, item) => sum + item.sous_total, 0);
    const profile = profileSnapshot.exists ? profileSnapshot.data() : {};
    const customerName = String(profile.nom || input.client_nom || '').trim();
    const customerPhone = String(profile.telephone || input.client_telephone || '').trim();
    if (!customerName || !customerPhone) {
        throw new HttpsError('failed-precondition', 'Le nom et le téléphone du profil sont nécessaires pour commander.');
    }

    const settingsRef = db.doc(DELIVERY_SETTINGS_PATH);
    const orderRef = db.collection('orders').doc(orderId);
    const requestedDate = typeof input.date_souhaitee === 'string' ? new Date(input.date_souhaitee) : null;
    const slotId = request.data?.slot_id;
    const slotDate = request.data?.slot_date;

    await db.runTransaction(async (transaction) => {
        const [existingOrder, settingsSnapshot] = await Promise.all([
            transaction.get(orderRef),
            transaction.get(settingsRef),
        ]);
        if (existingOrder.exists) {
            if (existingOrder.data().user_id !== request.auth.uid) {
                throw new HttpsError('already-exists', 'Cet identifiant de commande est déjà utilisé.');
            }
            return;
        }

        const settings = settingsSnapshot.exists ? settingsSnapshot.data() : { enabled: false };
        let scheduledAt = requestedDate;
        let chosenSlot = null;
        let usageRef = null;
        let usageSnapshot = null;

        if (settings.enabled) {
            if (typeof slotId !== 'string' || typeof slotDate !== 'string') {
                throw new HttpsError('failed-precondition', 'Choisis un créneau disponible avant de commander.');
            }
            chosenSlot = deliverySlotsForDate(settings, slotDate)
                .find((candidate) => candidate.id === slotId);
            if (!chosenSlot) {
                throw new HttpsError('failed-precondition', 'Ce créneau n’est plus disponible. Choisis-en un autre.');
            }
            usageRef = db.collection('delivery_slot_usage').doc(deliveryUsageId(slotDate, slotId));
            usageSnapshot = await transaction.get(usageRef);
            const reserved = usageSnapshot.exists ? Number(usageSnapshot.data().reserved_count) || 0 : 0;
            if (reserved >= chosenSlot.capacity) {
                throw new HttpsError('resource-exhausted', 'Ce créneau vient d’être complet. Choisis-en un autre.');
            }
            scheduledAt = new Date(chosenSlot.start_millis);
        } else if (!scheduledAt || Number.isNaN(scheduledAt.getTime()) || scheduledAt.getTime() < Date.now()) {
            throw new HttpsError('invalid-argument', 'Choisis une date et une heure valides.');
        }

        const orderData = {
            numero: String(input.numero || `CMD-${Math.floor(1000 + Math.random() * 9000)}`),
            user_id: request.auth.uid,
            client_nom: customerName,
            client_telephone: customerPhone,
            items: orderItems,
            sous_total: subtotal,
            mode_livraison: modeLivraison,
            ...(modeLivraison === 'livraison' ? {
                commune: String(input.commune).trim(),
                adresse_livraison: String(input.adresse_livraison).trim(),
            } : {}),
            frais_livraison: deliveryFee,
            total: subtotal + deliveryFee,
            mode_paiement: 'wave',
            statut_paiement: 'non_requis',
            statut_commande: 'en_attente_validation',
            date_souhaitee: Timestamp.fromDate(scheduledAt),
            historique_statuts: [{ statut: 'en_attente_validation', date: Timestamp.now() }],
            created_at: Timestamp.now(),
            ...(chosenSlot ? {
                delivery_slot_id: chosenSlot.id,
                delivery_slot_date: chosenSlot.date,
                delivery_slot_label: chosenSlot.time_label,
                delivery_slot_released: false,
            } : {}),
        };

        transaction.create(orderRef, orderData);
        if (usageRef && chosenSlot) {
            const reserved = usageSnapshot.exists ? Number(usageSnapshot.data().reserved_count) || 0 : 0;
            transaction.set(usageRef, {
                date: chosenSlot.date,
                slot_id: chosenSlot.id,
                reserved_count: reserved + 1,
                updated_at: FieldValue.serverTimestamp(),
            }, { merge: true });
        }
    });

    return { order_id: orderId, time_zone: DELIVERY_TIME_ZONE };
});

exports.onOrderCreated = onDocumentCreated('orders/{orderId}', async (event) => {
    const order = event.data.data();
    const orderId = event.params.orderId;
    const orderNumber = order.numero || orderId;
    const title = 'Nouvelle commande';
    const body = `Commande #${orderNumber} de ${order.client_nom || 'un client'} à prendre en charge.`;

    try {
        const db = getFirestore();
        const admins = await db.collection('users').where('role', '==', 'admin').get();

        await Promise.all(admins.docs.map(async (admin) => {
            const adminData = admin.data();

            if (adminData.fcm_token) {
                try {
                    await getMessaging().send({
                        token: adminData.fcm_token,
                        notification: { title, body },
                        data: { order_id: orderId, type: 'new_order' },
                    });
                } catch (pushError) {
                    console.error(`Erreur push admin ${admin.id} pour la commande ${orderId}:`, pushError);
                }
            }

            await admin.ref.collection('notifications').add({
                titre: title,
                corps: body,
                order_id: orderId,
                type: 'new_order',
                lu: false,
                created_at: FieldValue.serverTimestamp(),
            });
        }));

        console.log(`Notification de nouvelle commande envoyée à ${admins.size} admin(s): ${orderId}`);
    } catch (error) {
        console.error(`Erreur lors de la notification admin pour la commande ${orderId}:`, error);
    }

    return null;
});

exports.releaseDeliverySlot = onDocumentUpdated(
    { document: 'orders/{orderId}' },
    async (event) => {
        const orderId = event.params.orderId;
        const newData = event.data.after.data();

        if (!['refusee', 'annulee'].includes(newData.statut_commande) ||
            !newData.delivery_slot_id || !newData.delivery_slot_date ||
            newData.delivery_slot_released === true) {
            return null;
        }

        const db = getFirestore();
        const orderRef = db.collection('orders').doc(orderId);
        const usageRef = db.collection('delivery_slot_usage')
            .doc(deliveryUsageId(newData.delivery_slot_date, newData.delivery_slot_id));

        await db.runTransaction(async (transaction) => {
            const currentOrder = await transaction.get(orderRef);
            if (!currentOrder.exists) return;
            const currentData = currentOrder.data();
            if (!['refusee', 'annulee'].includes(currentData.statut_commande) ||
                currentData.delivery_slot_released === true) return;

            const usage = await transaction.get(usageRef);
            const reserved = usage.exists ? Number(usage.data().reserved_count) || 0 : 0;
            if (usage.exists) {
                transaction.update(usageRef, {
                    reserved_count: Math.max(0, reserved - 1),
                    updated_at: FieldValue.serverTimestamp(),
                });
            }
            transaction.update(orderRef, { delivery_slot_released: true });
        });

        return null;
    },
);

exports.reconcileDeliverySlotUsage = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Connecte-toi pour vérifier les créneaux.');
    }

    const db = getFirestore();
    const profile = await db.collection('users').doc(request.auth.uid).get();
    if (!profile.exists || profile.data().role !== 'admin') {
        throw new HttpsError('permission-denied', 'Cette opération est réservée à l’administration.');
    }

    const dateKey = request.data?.date;
    const parsedDate = parseDeliveryDateKey(dateKey);
    if (!parsedDate) {
        throw new HttpsError('invalid-argument', 'Date de créneau invalide.');
    }

    const ordersQuery = db.collection('orders').where('delivery_slot_date', '==', dateKey);
    const usageQuery = db.collection('delivery_slot_usage').where('date', '==', dateKey);
    const settingsRef = db.doc(DELIVERY_SETTINGS_PATH);
    const result = await db.runTransaction(async (transaction) => {
        const [ordersSnapshot, usageSnapshot, settingsSnapshot] = await Promise.all([
            transaction.get(ordersQuery),
            transaction.get(usageQuery),
            transaction.get(settingsRef),
        ]);

        const counts = new Map();
        const existingUsage = new Map();
        for (const usageDoc of usageSnapshot.docs) {
            const slotId = usageDoc.data().slot_id;
            if (typeof slotId !== 'string' || !slotId) continue;
            existingUsage.set(slotId, usageDoc);
            counts.set(slotId, 0);
        }

        const settings = settingsSnapshot.exists ? settingsSnapshot.data() : {};
        const weekday = parsedDate.date.getUTCDay() || 7;
        for (const slot of settings.slots || []) {
            if (slot.active !== false && Number(slot.weekday) === weekday && slot.id) {
                counts.set(String(slot.id), 0);
            }
        }

        for (const orderDoc of ordersSnapshot.docs) {
            const order = orderDoc.data();
            if (['annulee', 'refusee'].includes(order.statut_commande)) continue;
            if (typeof order.delivery_slot_id !== 'string' || !order.delivery_slot_id) continue;
            const slotId = order.delivery_slot_id;
            counts.set(slotId, (counts.get(slotId) || 0) + 1);
        }

        if (counts.size > 450) {
            throw new HttpsError('resource-exhausted', 'Trop de créneaux à vérifier pour une seule opération.');
        }

        let changedSlots = 0;
        let previousReservations = 0;
        let correctedReservations = 0;
        for (const [slotId, reservationCount] of counts) {
            const usageDoc = existingUsage.get(slotId);
            const previousCount = usageDoc?.exists
                ? Math.max(0, Number(usageDoc.data().reserved_count) || 0)
                : 0;
            previousReservations += previousCount;
            correctedReservations += reservationCount;
            if (previousCount !== reservationCount) changedSlots += 1;

            const usageRef = db.collection('delivery_slot_usage')
                .doc(deliveryUsageId(dateKey, slotId));
            if (reservationCount > 0 || usageDoc) {
                transaction.set(usageRef, {
                    date: dateKey,
                    slot_id: slotId,
                    reserved_count: reservationCount,
                    updated_at: FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        }

        return {
            checked_slots: counts.size,
            changed_slots: changedSlots,
            previous_reservations: previousReservations,
            corrected_reservations: correctedReservations,
        };
    });

    return { date: dateKey, ...result };
});

exports.onOrderUpdate = onDocumentUpdated('orders/{orderId}', async (event) => {
    const orderId = event.params.orderId;
    const oldData = event.data.before.data();
    const newData = event.data.after.data();

    // Vérifier si le statut_commande a changé
    if (oldData.statut_commande === newData.statut_commande) {
        return null;
    }

    const notifiableStatuses = ['acceptee', 'refusee', 'en_preparation', 'prete', 'livree'];
    const newStatus = newData.statut_commande;

    if (!notifiableStatuses.includes(newStatus)) {
        return null; // Statut non notifiable
    }

    const userId = newData.user_id;
    if (!userId) {
        console.warn(`Commande ${orderId} sans user_id. Pas de notification envoyée.`);
        return null;
    }

    try {
        const db = getFirestore();
        const userDoc = await db.collection('users').doc(userId).get();

        const userDocData = userDoc.data();
        if (!userDocData.fcm_token) {
            console.warn(`Aucun FCM token trouvé pour l'utilisateur ${userId}`);
            return null;
        }

        const token = userDocData.fcm_token;
        const notificationsEnabled = userDocData.notifications_enabled !== false; // true par défaut
        const orderNumber = newData.numero || orderId;

        // Préparer le contenu du message en fonction du statut
        let title = '';
        let body = '';

        switch (newStatus) {
            case 'acceptee':
                title = 'Bonne nouvelle !';
                body = `Votre commande #${orderNumber} a été acceptée, vous pouvez procéder au paiement.`;
                break;
            case 'refusee':
                title = 'Commande non disponible';
                body = newData.motif_refus ? `Motif: ${newData.motif_refus}` : `Votre commande #${orderNumber} a été refusée.`;
                break;
            case 'en_preparation':
                title = 'Préparation en cours';
                body = `Votre commande #${orderNumber} est en cours de préparation.`;
                break;
            case 'prete':
                title = 'Commande prête !';
                body = `Votre commande #${orderNumber} est prête pour le retrait ou la livraison.`;
                break;
            case 'livree':
                title = 'Commande livrée';
                body = `Votre commande #${orderNumber} a été livrée. Merci de votre confiance !`;
                break;
        }

        if (notificationsEnabled) {
            const payload = {
                token: token,
                notification: {
                    title: title,
                    body: body
                },
                data: {
                    order_id: orderId,
                    type: 'order_status_update'
                }
            };

            const response = await getMessaging().send(payload);
            console.log(`Notification envoyée avec succès pour la commande ${orderId}:`, response);
        } else {
            console.log(`Notification push désactivée pour l'utilisateur ${userId}, commande ${orderId}`);
        }

        // Écriture de la notification dans l'historique in-app
        try {
            await db.collection('users').doc(userId).collection('notifications').add({
                titre: title,
                corps: body,
                order_id: orderId,
                type: 'order_status_update',
                lu: false,
                created_at: FieldValue.serverTimestamp(), // Timestamp Firestore natif (compatible SDK Dart)
            });
            console.log(`Notification in-app écrite pour l'utilisateur ${userId}`);
        } catch (historyError) {
            console.error(`Erreur écriture historique notification pour ${userId}:`, historyError);
        }

    } catch (error) {
        console.error(`Erreur lors de l'envoi de la notification pour la commande ${orderId}:`, error);
    }
    
    return null;
});
