import aws from "aws-sdk";
import { sendMessage, getLocalTimeString } from "./utils.mjs";

const DISCORD_WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL;

const codecommit = new aws.CodeCommit({ apiVersion: "2015-04-13" });

export const handler = async (event, context) => {
  // retrieve relevant data from event record
  const repositoryName = event.Records[0].eventSourceARN.split(":")[5];
  const commitId = event.Records[0].codecommit.references[0].commit;
  const branch = event.Records[0].codecommit.references[0].ref.replace(
    "refs/heads/",
    ""
  );
  const userIdentity = event.Records[0].userIdentityARN
    .split(":")[5]
    .replace("user/", "");
  const eventName = event.Records[0].eventName;

  // assigning params object to variables for AWS SDK CodeCommit function call is
  const commitParams = {
    commitId,
    repositoryName,
  };

  // declaring this data here for value assignment inside the callback
  let commitMessage = "No commit message found.";

  // get the commit details
  await codecommit
    .getCommit(commitParams, function (err, data) {
      if (err) {
        let message =
          "Error getting commit metadata from commit ID: " + commitId;
        context.fail(message);
      } else {
        commitMessage = data.commit.message;
      }
    })
    .promise();

  await sendMessage(
    {
      embeds: [
        {
          author: {
            name: `${userIdentity}`,
          },
          title: "CodeCommit Notification",
          description: `**${userIdentity}** triggered an event (**${eventName}**) in the **${repositoryName}** repository's **${branch}** branch.`,
          color: 0x0ed67b,
          fields: [
            {
              name: "Commit Message",
              value: `${commitMessage}`,
            },
          ],
          footer: {
            text: getLocalTimeString(),
          },
        },
      ],
    },
    DISCORD_WEBHOOK_URL
  ).catch((error) => {
    console.error(error);
  });

  const response = {
    statusCode: 200,
    body: JSON.stringify("Success!"),
  };
  return response;
};
