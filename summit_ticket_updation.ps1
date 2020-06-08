<#

Name      : SymphonySummit Integration

Version   : 1.0

Developer : CIS - Automation Factory

Features  : read and update ticket data in symphony summit

Description : This will read the details and update the status in symphony summit

#>
#Summit - Data
$user = "hoautomation@gtaa.com"
$pass = "Welcome@123"
$org_ID = "1"
$Instance = "IT"

$summit_uri = "https://itservicedeskportaldev.ppcgtaa.com/API/REST/Summit_RESTWCF.svc/RestService/CommonWS_JsonObjCall"

$proxy = "{'ReturnType': 'JSON','Password': '$pass' ,'UserName': '$user'}"
$id = "ticket number"


#Summit escalation
$escalate_Asignee = ""
$escalate_Assignee_mail= "bharat.peddakota@wipro.com"
$escalate_state="In-Progress"
$escalate_log = "ticket is not picked by Healix"
$escalate_workgroup = "INF-MONITORING"

function rest_Api_call{
    [cmdletbinding()]
     param(
         $body_data,$action
            )

            try{
                Write-Host "in restcall"
                $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, $pass)))

                # Set proper headers
                $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $headers.Add('Authorization',('Basic {0}' -f $base64AuthInfo))
                $headers.Add('Accept','application/json')
                $headers.Add('Content-Type','application/json')

                $method = "post"
                
                $data = $body_data.Replace("'",'"')
                #Write-Host $data
                $response = Invoke-WebRequest -Headers $headers -Method $method -Uri $summit_uri -Body $data
                #Write-Host $response
                
                $res_val = $response.RawContent.Split("`n")[-1] | ConvertFrom-Json
                if($action -like "*update*"){
                    return $res_val
                }
                else{
                    return $res_val.OutputObject
                    }
        
            }
            catch{
                 $_
                 return "API is NotReachable"
            }
 }

 try{
                
                
                
                ###################
                #fetch Short description
                $inc_body = "{ 
                               ""ServiceName"":""IM_GetIncidentDetailsAndChangeHistory"",
                               ""objCommonParameters"":
                                   { 
                                        '_ProxyDetails':$proxy,
                                        'TicketNo':$id
                                    } 
                              } "
                #summit rest call
                $sub_data = rest_Api_call -body_data $inc_body
                if ($sub_data -notlike "*NotReachable*"){
                    $complete_Data = $sub_data.IncidentDetails.TicketDetails
                    #Write-Host $complete_Data 
                    $short_Desc = $complete_Data.Subject
                    ###################
                    $sup_func = $complete_Data.Sup_Function
                    if(($complete_Data.Classification).Length -ge 2){
                        $classification = $complete_Data.Classification.split('\')[-1]
                        }
                    $caller_mail = $complete_Data.Caller_EmailID
                    $urgency = $complete_Data.Impact_Name
                    $impact = $complete_Data.Criticality_Name
                    if(($complete_Data.PriorityName) -ge 2){
                        $priority = $complete_Data.PriorityName
                    }
                    
                    if(($complete_Data.OpenCategory).Length -ge 2){
                        $open_cat = $complete_Data.OpenCategory.split('\')[-1]
                        }
                    $sla = $complete_Data.SLA_Name

                    #Healix Rest call
                    
                    $id
                    
                        #Summit Rest call for escalation
                        
                        write-host "update incident note"
                        $es_container_string ='{\"Updater\":\"Executive\",\"Ticket\":{\"Ticket_No\":\"'+$id+'\",\"IsFromWebService\":\"True\",\"Sup_Function\":\"'+$sup_func+'\",\"Caller_EmailId\":\"'+$caller_mail+'\",\"Medium\":\"Web\",\"Status\":\"'+$escalate_state+'\",\"PageName\":\"TicketDetail\",\"Classification_Name\":\"'+$classification+'\",\"Urgency_Name\":\"'+$urgency+'\",\"Impact_Name\":\"'+$impact+'\",\"Priority_Name\":\"'+$priority+'\",\"OpenCategory_Name\":\"'+$open_cat+'\",\"Assigned_WorkGroup_Name\":\"'+$escalate_workgroup+'\",\"SLA_Name\":\"'+$sla+'\",\"Assigned_Engineer_Name\":\"'+$escalate_Asignee+'\",\"Assigned_Engineer_Email\":\"'+$escalate_Assignee_mail+'\"},\"TicketInformation\":{\"UserLog\":\"'+$update_log+'\"}}'
                        Write-Host $es_container_string
                        $es_body_data = "{
                                    ""ServiceName"":""IM_LogOrUpdateIncident"",
                                    ""objCommonParameters"":
                                    {
                                        ""_ProxyDetails"":$proxy,
                                        ""incidentParamsJSON"":
                                        {
                                            ""IncidentContainerJson"": '$es_container_string'},
                                             'RequestType':'RemoteCall'}
                                   }"
    
                    $es_data = rest_Api_call -body_data $es_body_data -action "update"
                    if ($es_data -notlike "*NotReachable*"){
                        (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd_HH:mm:ss")+ " ticket : $id escalated successfully `n $es_container_string" | Out-File "logs.txt" -Append -Force
                        $es_data.Errors | Out-File "logs.txt" -Append -Force
                        $es_data.Message | Out-File "logs.txt" -Append -Force
                    }
                    else{
                        (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd_HH:mm:ss")+ " ticket : $id escalation is failed `n $es_container_string" | Out-File "logs.txt" -Append -Force
                        $es_data.Errors | Out-File "logs.txt" -Append -Force
                        $es_data.Message | Out-File "logs.txt" -Append -Force
                    }
                    }
                    
            
 
}
catch{
    $_
}
