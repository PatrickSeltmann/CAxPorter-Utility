# CA00001-Global-BaseProtection-AllApps-AnyPlatform-BlockNonPersonas

## Summary
This Conditional Access Policy is designed to enhance security by blocking access to all applications for non-persona users across any platform. It applies globally, with specific exclusions for certain user groups and roles. The policy is currently enabled and ensures that only designated personas can access the organization's resources.

## Conditions

### Users
- **Included Users**: All users are included by default.
- **Excluded Users**: 
  - Users from all external tenants, including internal guests and various types of external users.
  - Specific groups are excluded, such as:
    - CA-Persona-Global-BaseProtection-Exclusions
    - CA-Persona-Admins
    - CA-Persona-AzureServiceAccounts
    - CA-Persona-BreakGlassAccounts
    - CA-Persona-CorpServiceAccounts
    - CA-Persona-Externals
    - CA-Persona-GuestAdmins
    - CA-Persona-Internals
    - CA-Persona-Microsoft365ServiceAccounts
    - CA-Persona-Guests
    - CA-Persona-Developers
    - CA-Persona-WorkloadIdentities
- **Excluded Roles**: Directory Synchronization Accounts

### Applications
- **Included Applications**: None specified, implying all applications are covered.
- **Excluded Applications**: None specified.

### Client Applications
- **Client App Types**: All client applications are included.

## Grant Controls
- **Built-In Controls**: The policy uses a "block" control to deny access.
- **Operator**: OR (indicating that any of the specified conditions will trigger the block).

## State
- **Policy State**: Enabled

This policy is part of a broader security strategy to protect organizational resources by restricting access to non-persona users while allowing necessary exceptions for specific groups and roles.
