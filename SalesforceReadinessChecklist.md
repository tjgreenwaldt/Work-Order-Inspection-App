# Salesforce Readiness Checklist

- Connected App needed.
- OAuth Authorization Code with PKCE.
- Client ID needed.
- Redirect URI needed.
- Login domain needed.
- API version needed.
- Sandbox vs production base URL needed.
- Required scopes: `api`, `refresh_token`, `openid`, `profile`.
- Read-only integration should be wired before writeback.
- First real methods to wire:
  - `fetchSites()`
  - `fetchWorkOrders(siteId:scheduledDate:)`
  - `fetchWorkTasks(workOrderId:)`
  - `fetchWorkTaskSteps(workTaskIds:)`
- Do not update Work Order status.
- Do not update Work Task inspection completed field.
- Step writeback target is `pffsm__Work_Task_Step__c` only.
- Photos will use `ContentVersion` and `ContentDocumentLink` tied to Work Task Step.
