# CA01002-Breakglass-AttackSurfaceReduction-AllApps-AnyPlatform-BlockUnknownPlatforms

## Summary
This Conditional Access Policy is designed to enhance security by reducing the attack surface for breakglass accounts. It targets all applications and platforms, specifically blocking access from unknown platforms. The policy is currently enabled for reporting but not enforced, allowing administrators to monitor its impact without affecting user access.

## Conditions

### Platforms
- **Included Platforms:** All platforms
- **Excluded Platforms:** Android, iOS, Windows, macOS, Linux

### Applications
- **Included Applications:** None
- **Excluded Applications:** None

### Users and Groups
- **Included Groups:** CA-Persona-BreakGlassAccounts
- **Excluded Users, Guests, Groups, and Roles:** None

### Client Applications
- **Client App Types:** All

## Grant Controls
- **Built-In Controls:** Block access
- **Operator:** OR

## State
- **Policy State:** Enabled for reporting but not enforced

This policy is specifically targeted at breakglass accounts to ensure that access is blocked from any unknown or untrusted platforms while allowing administrators to review the policy's effectiveness through reporting.
