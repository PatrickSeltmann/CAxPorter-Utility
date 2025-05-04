# CA02004-Admins-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth

## Summary

The "CA02004-Admins-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth" policy is designed to enhance security for administrative accounts by blocking legacy authentication methods across all applications. This policy targets specific administrative groups while excluding certain service accounts and break-glass accounts to ensure operational continuity.

## Conditions

### Applications
- **Include Applications**: All applications are included.
- **Exclude Applications**: No applications are explicitly excluded.

### Users
- **Include Groups**: 
  - CA-Persona-Admins
- **Exclude Groups**: 
  - CA-Persona-Admins-Excluded-IdentityProtection
  - CA-Persona-AzureServiceAccounts
  - CA-Persona-BreakGlassAccounts
  - CA-Persona-CorpServiceAccounts
  - CA-Persona-Microsoft365ServiceAccounts

### Client Application Types
- **Included Client App Types**:
  - Exchange ActiveSync
  - Other

## Grant Controls

- **Built-In Controls**: 
  - Block legacy authentication methods.
- **Operator**: OR

## State

- The policy is currently **enabled**.

## Additional Information

- **Policy ID**: c9681c73-f853-4f13-9e33-21067fd3ef4b
- **Created Date**: July 10, 2024
- **Modified Date**: April 17, 2025

This policy ensures that administrative accounts are protected by blocking less secure legacy authentication protocols, thereby reducing the risk of unauthorized access.
