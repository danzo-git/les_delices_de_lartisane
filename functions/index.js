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