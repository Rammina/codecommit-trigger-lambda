import fetch from "node-fetch";

// function for sending an async message that returns a promise
export function sendMessage(payload, webhookUrl) {
  const data = typeof payload === "string" ? { content: payload } : payload;

  return new Promise((resolve, reject) => {
    fetch(webhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    })
      .then((response) => {
        if (!response.ok) {
          reject(
            new Error(`Could not send message: ${response.status}. 
          `)
          );
        }
        resolve();
      })
      .catch((error) => {
        reject(error);
      });
  });
}

// get the current date and time and output it in this format: MM/DD/YY - HH:mm Timezone e.g. '3/16/23 - 11:15PM America/New_York' (local machine time)
export const getLocalTimeString = () => {
  const timestamp = new Intl.DateTimeFormat("en-US", {
    dateStyle: "short",
    timeStyle: "short",
  })
    .format(new Date())
    .replace(",", " -");
  const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  return `${timestamp} ${timezone}`;
};
