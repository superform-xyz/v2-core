import { Context } from '@tenderly/actions';

interface IncidentIoConfig {
  [key: string]: {
    link: string;
    secret: string;
  };
}

const incidentIoInfo: IncidentIoConfig = {
  sev1: {
    link: 'incidentIoSev1Webhook',
    secret: 'incidentIoSev1Secret'
  },
  sev2: {
    link: 'incidentIoSev2Webhook', 
    secret: 'incidentIoSev2Secret'
  },
  sev3Protocol: {
    link: 'incidentIoSev3WebhookProtocol',
    secret: 'incidentIoSev3SecretProtocol'
  },
  sev3Backend: {
    link: 'incidentIoSev3WebhookBackend',
    secret: 'incidentIoSev3SecretBackend'
  },
  sev4Protocol: {
    link: 'incidentIoSev4WebhookProtocol',
    secret: 'incidentIoSev4SecretProtocol'
  },
  sev4Backend: {
    link: 'incidentIoSev4WebhookBackend', 
    secret: 'incidentIoSev4SecretBackend'
  }
};

export const notifyIncidentIo = async (
  severity: string,
  title: string,
  description: string,
  key: string,
  context: Context
) => {
  console.log('Sending to Incident.io:', `🚨 ${title}`);
  console.log(description);

  const webHookSecretLink = incidentIoInfo[severity].link;
  const webHookSecret = incidentIoInfo[severity].secret;

  const webhookLink = await context.secrets.get(webHookSecretLink);

  // Add randomness to key for unique incidents (except for specific recurring keys)
  const specialKeys = [
    'rebalanceActionsPendingProd', 
    'rebalanceActionsPendingStaging',
    'notEnoughFundsForRebalanceProd',
    'notEnoughFundsForRebalanceStaging'
  ];
  
  if (!specialKeys.includes(key)) {
    key = key + Math.random().toString();
  }

  try {
    const response = await fetch(webhookLink, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': await context.secrets.get(webHookSecret)
      },
      body: JSON.stringify({
        title,
        description,
        deduplication_key: key,
        status: 'firing',
        metadata: {
          team: 'core',
          service: 'superform-v2'
        }
      })
    });

    if (!response.ok) {
      console.error('Failed to send incident:', response.status, response.statusText);
    } else {
      console.log('Incident sent successfully to Incident.io');
    }
  } catch (error) {
    console.error('Error sending incident to Incident.io:', error);
  }
};