# Gemini Data Analytics Agent Integration Guide

This guide documents the infrastructure, IAM policies, and REST API structures required to successfully connect your Adobe ColdFusion application (running on Cloud Run) to the Google Cloud Gemini Data Analytics Agent.

---

## 🔑 1. Secret Manager Configuration

The application expects the Gemini Data Agent ID to be loaded dynamically from Google Secret Manager.

* **Secret Name:** `alloydb-ca-data-agent-id`
* **Secret Value Format:** `agent_{UUID}` (e.g. `agent_12345678-abcd-1234-abcd-123456789abc`)

> [!IMPORTANT]
> **GCP Label Constraint:** The agent ID **must** start with the `agent_` prefix. When creating a conversation, Google's backend registers the agent ID as a resource label key. GCP label keys cannot start with a number. Prefixing the UUID with `agent_` avoids a `400 Bad Request` validation crash on conversation creation.

---

## 🛡️ 2. IAM Policy Bindings

The Cloud Run service account (e.g. `PROJECT_NUMBER-compute@developer.gserviceaccount.com`) must have the following roles bound at the project level to authorize agent querying and conversation state storage:

### A. Gemini Data Analytics Access
* **Role:** `roles/geminidataanalytics.dataAgentUser`
* **Purpose:** Grants permission to list, get, and execute chat queries (`geminidataanalytics.dataAgents.chat`) against your published agent.

### B. Cloud AI Companion (Session Storage) Access
* **Role:** `roles/cloudaicompanion.admin`
* **Purpose:** Grants permission to write, read, and delete companion topic threads (`cloudaicompanion.topics.get` / `cloudaicompanion.topics.create`) which are used to maintain session history.

### Command to Apply:
```bash
# Grant Agent Chat User
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:YOUR_SERVICE_ACCOUNT_EMAIL" \
  --role="roles/geminidataanalytics.dataAgentUser"

# Grant AI Companion Session Admin
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:YOUR_SERVICE_ACCOUNT_EMAIL" \
  --role="roles/cloudaicompanion.admin"
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
