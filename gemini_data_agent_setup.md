# Gemini Data Analytics Agent Integration Guide

This guide documents the infrastructure, IAM policies, and REST API structures required to successfully connect your Adobe ColdFusion application (running on Cloud Run) to the Google Cloud Gemini Data Analytics Agent.

---

## 🔑 1. Secret Manager Configuration

The application expects the Gemini Data Agent ID to be loaded dynamically from Google Secret Manager.

* **Secret Name:** `vertex-agent-id`
* **Secret Value Format:** `agent_{UUID}` (e.g. `agent_00000000-0000-0000-0000-000000000000`)

> [!IMPORTANT]
> **GCP Label Constraint:** The agent ID **must** start with the `agent_` prefix. When creating a conversation, Google's backend registers the agent ID as a resource label key. GCP label keys cannot start with a number. Prefixing the UUID with `agent_` avoids a `400 Bad Request` validation crash on conversation creation.

---

## 🛡️ 2. IAM Policy Bindings

The Cloud Run service account (`cf-brews-sa@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com`) must have the following least-privilege roles bound at the project level to authorize agent querying and conversation state storage:

### A. Gemini Data Analytics Access
* **Role:** `roles/geminidataanalytics.dataAgentUser`
* **Purpose:** Grants permission to list, get, and execute chat queries (`geminidataanalytics.dataAgents.chat`) against your published agent.

### B. Cloud AI Companion (Least-Privilege Session Storage) Access
* **Roles:** `roles/cloudaicompanion.user` + Custom Role `projects/YOUR_GCP_PROJECT_ID/roles/cfBrewsCompanionSessionUser`
* **Purpose:** Grants least-privilege permission to create and read companion topic threads (`cloudaicompanion.topics.get` / `cloudaicompanion.topics.create`) used to maintain session history, avoiding project-wide `*admin` roles.

### Command to Apply:
```bash
# Grant Agent Chat User
gcloud projects add-iam-policy-binding YOUR_GCP_PROJECT_ID \
  --member="serviceAccount:cf-brews-sa@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/geminidataanalytics.dataAgentUser"

# Grant Least-Privilege AI Companion Session User
gcloud projects add-iam-policy-binding YOUR_GCP_PROJECT_ID \
  --member="serviceAccount:cf-brews-sa@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="projects/YOUR_GCP_PROJECT_ID/roles/cfBrewsCompanionSessionUser"
```

---

## 📡 3. REST API Integration Pipeline

Communicating with the Gemini Data Agent requires a **two-step HTTP sequence** targeting the **`global`** region endpoint.

### Step 1: Create the Conversation Resource
Before chatting, you must initialize a persistent conversation resource mapped to your agent.

* **HTTP Method:** `POST`
* **Endpoint:** `https://geminidataanalytics.googleapis.com/v1beta/projects/{projectId}/locations/global/conversations`
* **Request Headers:**
  * `Authorization: Bearer {accessToken}`
  * `Content-Type: application/json`
* **Request Body:**
  ```json
  {
    "agents": [
      "projects/{projectId}/locations/global/dataAgents/agent_{agentUuid}"
    ]
  }
  ```
* **Success Response (200 OK):**
  Capture the value of the `"name"` field from the JSON response. This is the unique resource path of the created conversation.
  ```json
  {
    "name": "projects/{projectId}/locations/global/conversations/{conversationUuid}",
    "agents": [ ... ],
    "createTime": "..."
  }
  ```

---

### Step 2: Execute the Chat Turn
Send the user's natural language query using the conversation path created in Step 1.

* **HTTP Method:** `POST`
* **Endpoint:** `https://geminidataanalytics.googleapis.com/v1beta/projects/{projectId}/locations/global:chat`
* **Request Headers:**
  * `Authorization: Bearer {accessToken}`
  * `Content-Type: application/json`
* **Request Body:**
  ```json
  {
    "parent": "projects/{projectId}/locations/global",
    "client_id": "ALLOYDB",
    "conversation_reference": {
      "conversation": "projects/{projectId}/locations/global/conversations/{conversationUuid}",
      "data_agent_context": {
        "data_agent": "projects/{projectId}/locations/global/dataAgents/agent_{agentUuid}"
      }
    },
    "messages": [
      {
        "user_message": {
          "text": "Show me active batches"
        }
      }
    ]
  }
  ```
* **Response:**
  Returns a JSON array of events showing the agent's thought process, the generated AlloyDB SQL query, and the result data:
  ```json
  [
    {
      "timestamp": "...",
      "systemMessage": {
        "data": {
          "generatedSql": "SELECT ... FROM brews.recipes LIMIT 5;"
        }
      }
    },
    {
      "timestamp": "...",
      "systemMessage": {
        "data": {
          "result": {
            "data": [ { ... } ],
            "schema": { ... }
          }
        }
      }
    }
  ]
  ```
