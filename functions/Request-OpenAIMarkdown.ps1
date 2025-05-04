<#
.SYNOPSIS
Sends a Conditional Access Policy JSON to the OpenAI API and receives a Markdown-formatted documentation string.

.DESCRIPTION
This function formats a Conditional Access policy into a structured prompt and sends it to the OpenAI chat completion endpoint (default: GPT-4o).
It returns a Markdown-formatted documentation string that can be saved or processed further.

OpenAI API temperature value explained: 

Value   | Behavior              | Application 
0.0     | Very deterministic    | almost identical answers
0.3     | Less creative         | rather precise and consistent Good for technical documentation, facts
0.7     | More variation        | alternative formulations Suitable for creative texts, for example
1.0+    | Very creative         | but may also be imprecise For brainstorming, fiction etc.

.PARAMETER PolicyName
The display name of the Conditional Access policy (used for logging and output context).

.PARAMETER CAPolicyJSON
The Conditional Access policy in JSON string format.

.PARAMETER Key
Your OpenAI API key used for authentication.

.PARAMETER Endpoint
(Optional) Custom OpenAI API endpoint. Defaults to https://api.openai.com/v1/chat/completions.

.EXAMPLE
$md = Request-OpenAIMarkdown -PolicyName "MyPolicy" -CAPolicyJSON $json -Key $OpenAIKey

.NOTES
    Author: Patrick Seltmann  
    Version: 0.1.0 
    Created: 2025-05-03  
    Prerequisites: 
    - Microsoft.Graph PowerShell SDK
    - PowerShell V7
#>
function Request-OpenAIMarkdown {
    param (
        [string]$PolicyName,
        [string]$CAPolicyJSON,
        [string]$Key,
        [string]$Endpoint = "https://api.openai.com/v1/chat/completions"
    )

    # System message to set the assistant’s role and tone
    $systemMessage = "You are a technical documentation assistant. You help document Conditional Access Policies in Markdown format, which are provided in JSON structure. The target audience is IT administrators."

    # Construct the user prompt with JSON content to be documented
    $OpenAIPrompt = @"
Document the following Conditional Access Policy for IT administrators in Markdown format. Use H1 for the policy name, H2 for sections (Conditions, Grant Controls, etc.), and use bullet points and text. Create a summary of the policy at the beginning.

JSON of the policy:
$CAPolicyJSON
"@

    # Combine system and user messages    
    $OpenAIMessages = @(
        @{ role = "system"; content = $systemMessage },
        @{ role = "user"; content = $OpenAIPrompt }
    )

    # Prepare request body
    $OpenAIBody = @{
        model       = "gpt-4o"
        messages    = $OpenAIMessages
        temperature = 0.3
    } | ConvertTo-Json -Depth 3 -Compress

    # Prepare HTTP headers with API key
    $OpenAIHeaders = @{
        "Authorization" = "Bearer $Key"
        "Content-Type"  = "application/json"
    }

    for ($i = 1; $i -le 3; $i++) {
        try {
            # Send POST request to OpenAI API
            $OpenAIResponse = Invoke-RestMethod -Uri $Endpoint -Headers $OpenAIHeaders -Method POST -Body $OpenAIBody
            
            # Return the content of the first message in the response nhh
            return $OpenAIResponse.choices[0].message.content
        }
        catch {
            # Handle rate limiting: wait and retry
            if ($_.Exception.Response.StatusCode.Value__ -eq 429 -and $i -lt 3) {
                Write-Warning "Rate limit reached. Retrying in 10 seconds... (Attempt $i)"
                
                Start-Sleep -Seconds 10

            }
            else {
                Write-Warning "Error with OpenAI API for $PolicyName : $($_.Exception.Message)"
                
                return ""
            }
        }
    }
}
