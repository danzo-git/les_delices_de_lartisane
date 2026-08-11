const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

const admin = require('firebase-admin');
const axios = require('axios');
const crypto = require('crypto');

admin.initializeApp();

const geniusPayPublicKey = defineSecret('GENIUS_PAY_PUBLIC_KEY');
const geniusPaySecretKey = defineSecret('GENIUS_PAY_SECRET_KEY');

const GENIUS_PAY_API_URL =
  'https://geniuspay.ci/api/v1/merchant/payments';

exports.createPayment = onCall(
  {
    secrets: [geniusPayPublicKey, geniusPaySecretKey],
  },
  async (request) => {
    // 1. Vérifier l'authentification
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'Utilisateur non connecté.'
      );
    }

    const data = request.data;
    const orderId = data.orderId;

    if (!orderId) {
      throw new HttpsError(
        'invalid-argument',
        'orderId est requis.'
      );
    }

    try {
      // 2. Récupérer la commande
      const orderSnapshot = await admin
        .firestore()
        .collection('orders')
        .doc(orderId)
        .get();

      if (!orderSnapshot.exists) {
        throw new HttpsError(
          'not-found',
          'Commande introuvable.'
        );
      }

      const orderData = orderSnapshot.data();

      // 3. Appel à GeniusPay
      const response = await axios.post(
        GENIUS_PAY_API_URL,
        {
          amount: orderData.total,
          description: `Commande #${orderData.numero}`,
          customer: {
            name: orderData.client_nom,
            phone: orderData.client_telephone,
          },
          metadata: {
            order_id: orderId,
          },
        },
        {
          headers: {
            'X-API-Key': geniusPayPublicKey.value(),
            'X-API-Secret': geniusPaySecretKey.value(),
            'Content-Type': 'application/json',
          },
        }
      );

      // 4. Retourner l'URL de checkout
      if (response.data?.checkout_url) {
        return {
          checkout_url: response.data.checkout_url,
        };
      }

      throw new Error(
        'checkout_url manquant dans la réponse de GeniusPay'
      );
    } catch (error) {
      console.error(
        'Erreur lors de la création du paiement GeniusPay:',
        error
      );

      // Préserver les HttpsError déjà créées
      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        'internal',
        "Impossible d'initier le paiement.",
        error.message
      );
    }
  }
);

exports.geniusPayWebhook = onRequest(
  {
    secrets: [geniusPaySecretKey],
  },
  async (req, res) => {
    try {
      const signature = req.headers['x-webhook-signature'];
      const timestamp = req.headers['x-webhook-timestamp'];

      const payload = req.rawBody
        ? req.rawBody.toString()
        : JSON.stringify(req.body);

      // Validation du timestamp
      if (timestamp) {
        const timeDiff = Math.abs(
          Date.now() / 1000 - parseInt(timestamp, 10)
        );

        if (timeDiff > 300) {
          return res
            .status(400)
            .send('Timestamp invalide ou expiré');
        }
      }

      // Validation de la signature HMAC
      if (signature) {
        const stringToSign = `${timestamp}.${payload}`;

        const expectedSignature = crypto
          .createHmac(
            'sha256',
            geniusPaySecretKey.value()
          )
          .update(stringToSign)
          .digest('hex');

        if (signature !== expectedSignature) {
          console.warn('Signature invalide');

          return res
            .status(403)
            .send('Signature invalide');
        }
      }

      const data = req.body;

      const orderId = data.metadata?.order_id;
      const eventType = data.event;

      if (!orderId) {
        return res
          .status(400)
          .send('order_id manquant');
      }

      const orderRef = admin
        .firestore()
        .collection('orders')
        .doc(orderId);

      const orderSnapshot = await orderRef.get();

      if (!orderSnapshot.exists) {
        return res
          .status(404)
          .send('Commande non trouvée');
      }

      let newPaymentStatus = 'en_attente';
      let newOrderStatus =
        orderSnapshot.data().statut_commande;

      if (eventType === 'payment.success') {
        newPaymentStatus = 'confirme';
        newOrderStatus = 'en_preparation';
      } else if (
        eventType === 'payment.failed' ||
        eventType === 'payment.cancelled' ||
        eventType === 'payment.expired'
      ) {
        newPaymentStatus = 'echoue';
      }

      const historyEntry = {
        statut:
          eventType === 'payment.success'
            ? 'paiement_confirme'
            : 'paiement_echoue',

        date: admin.firestore.Timestamp.now(),
      };

      await orderRef.update({
        statut_paiement: newPaymentStatus,
        statut_commande: newOrderStatus,

        historique_statuts:
          admin.firestore.FieldValue.arrayUnion(
            historyEntry
          ),
      });

      return res
        .status(200)
        .send('Webhook traité avec succès');
    } catch (error) {
      console.error('Erreur webhook:', error);

      return res
        .status(500)
        .send('Erreur interne du serveur');
    }
  }
);