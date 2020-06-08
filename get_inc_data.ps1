<#

Name      : SymphonySummit Integration

Version   : 1.0

Developer : CIS - Automation Factory

Features  : read ticket data from symphony summit and push the ticket to healix

Description : This will read the details from symphony summit and push the data to healix.depending ph the alert generation status on healix this will update the status in symphony summit

#>

#Healix -Data
$Account_ID = "205"
$Apikey = "8D5A6AE6A37AC13"
$healix_Url = "http://10.181.11.53:8080/api/Agent/PushAlert/"

#Summit - Data
$user = "hoautomation@gtaa.com"
$pass = "Welcome@123"
$org_ID = "1"
$Instance = "IT"
$State = "Open"
$work_group = "SERVICE DESK"#"INF-MONITORING"
$servicename = "IM_GetIncidentList"
$summit_uri = "https://itservicedeskportaldev.ppcgtaa.com/API/REST/Summit_RESTWCF.svc/RestService/CommonWS_JsonObjCall"

$proxy = "{'ReturnType': 'JSON','Password': '$pass' ,'UserName': '$user'}"
$filter = "{'OrgID': '$org_ID' ,'Instance': '$Instance' ,'Status': '$State','WorkgroupName': '$work_group'}"
$commom_parm ="{'_ProxyDetails': $proxy ,'objIncidentCommonFilter': $filter}"

#SUmmit updation
$update_workgroup = "INF-AUTOMATION"
$update_Assignee_mail = "hoautomation@gtaa.com"
$update_Assignee = "Hiro Automation"
$update_state = "In-Progress"
$update_log = "Healix is trying to resolve the issue"

#Summit escalation
$escalate_Asignee = ""
$escalate_Assignee_mail= "bharat.peddakota@wipro.com"
$escalate_state="In-Progress"
$escalate_log = "ticket is not picked by Healix"
$escalate_workgroup = "INF-MONITORING"


try{

#functon to push data to Healix
        function push_to_healix{
        [cmdletbinding()]
            param(
                $inc_host,$short_Desc,$id
            )
            try{
                $head = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                $head.Add('apikey',$Apikey)
                $head.Add('Accept','application/json')
                $head.Add('Content-Type','application/json')

                $healix_Body = "{
                                  ""AccountId"": ""$Account_ID"",
                                  ""HostName"": ""$inc_host"",
                                  ""AlertDescription"": ""$short_Desc"",
                                  ""ITSMTicketId"": ""$id"",
                                  ""ManualParameterIdentificationRequired"": ""False""
                                }"

                $short_Desc

                $Res = Invoke-RestMethod -Method 'Post' -Uri $healix_Url -Body $healix_Body -Headers $head

                #$Res.IsFailure
                #$Res.Msg
                if($Res.IsFailure -like "*True*"){
                    
                    return $Res.Msg
                }
                if($Res.IsFailure -like "*False*"){
                    
                    return "successfull"
                }

            }
            catch{
                $_
            
            }
        
        }

        #Rest API call to summit
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
        
        #fetch all the data from a work group
        $body = "{
                    ""ServiceName"": ""$servicename"",
                    ""objCommonParameters"": $commom_parm
                 }"
        #summit rest call
        $read_output = rest_Api_call -body_data $body
        if ($read_output -notlike "*NotReachable*"){
            $Inc_ID = "Incident ID" 
            $config_item = "IT_Event Details_Configuration Item"
            $ticket_dump = $read_output.MyTickets
    
            foreach($ticket in $ticket_dump){
                $id = $ticket.$Inc_ID
                $inc_host = $ticket.$config_item
                
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
                    $healix_status = push_to_healix -inc_host $inc_host -short_Desc $short_Desc -id $id
                    $id
                    if($healix_status -like "successfull"){
                        write-host "update incident with success note"

                        #Summit Rest call for updation
                        $up_container_string = '{\"Updater\":\"Executive\",\"Ticket\":{\"Ticket_No\":\"'+$id+'\",\"IsFromWebService\":\"True\",\"Sup_Function\":\"'+$sup_func+'\",\"Caller_EmailId\":\"'+$caller_mail+'\",\"Medium\":\"Web\",\"Status\":\"'+$update_state+'\",\"PageName\":\"TicketDetail\",\"Classification_Name\":\"'+$classification+'\",\"Urgency_Name\":\"'+$urgency+'\",\"Impact_Name\":\"'+$impact+'\",\"Priority_Name\":\"'+$priority+'\",\"OpenCategory_Name\":\"'+$open_cat+'\",\"Assigned_WorkGroup_Name\":\"'+$update_workgroup+'\",\"SLA_Name\":\"'+$sla+'\",\"Assigned_Engineer_Name\":\"'+$update_Assignee+'\",\"Assigned_Engineer_Email\":\"'+$update_Assignee_mail+'\"},\"TicketInformation\":{\"UserLog\":\"'+$update_log+'\"}}'
                        Write-Host $up_container_string
                        $up_body_data = "{
                                    ""ServiceName"":""IM_LogOrUpdateIncident"",
                                    ""objCommonParameters"":
                                    {
                                        ""_ProxyDetails"":$proxy,
                                        ""incidentParamsJSON"":
                                        {
                                            ""IncidentContainerJson"": '$up_container_string'},
                                             'RequestType':'RemoteCall'}
                                   }"

                    $up_data = rest_Api_call -body_data $up_body_data -action "update"
                    if ($up_data -notlike "*NotReachable*"){
                        (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd_HH:mm:ss")+ " ticket : $id updated successfully `n $es_container_string" | Out-File "logs.txt" -Append -Force
                        $up_data.Errors | Out-File "logs.txt" -Append -Force
                        $up_data.Message | Out-File "logs.txt" -Append -Force
                    }
                    else{
                        (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd_HH:mm:ss")+ " ticket : $id updation is failed `n $es_container_string" | Out-File "logs.txt" -Append -Force
                        $up_data.Errors | Out-File "logs.txt" -Append -Force
                        $up_data.Message | Out-File "logs.txt" -Append -Force
                    }
                    }
                    else{
                        #Summit Rest call for escalation
                        $healix_notes = ([string]$healix_status).Replace("'","*").Replace('"',"*").Replace("\","*").Replace("`n","*****")
                        write-host "update incident with failure note"
                        $es_container_string ='{\"Updater\":\"Executive\",\"Ticket\":{\"Ticket_No\":\"'+$id+'\",\"IsFromWebService\":\"True\",\"Sup_Function\":\"'+$sup_func+'\",\"Caller_EmailId\":\"'+$caller_mail+'\",\"Medium\":\"Web\",\"Status\":\"'+$escalate_state+'\",\"PageName\":\"TicketDetail\",\"Classification_Name\":\"'+$classification+'\",\"Urgency_Name\":\"'+$urgency+'\",\"Impact_Name\":\"'+$impact+'\",\"Priority_Name\":\"'+$priority+'\",\"OpenCategory_Name\":\"'+$open_cat+'\",\"Assigned_WorkGroup_Name\":\"'+$escalate_workgroup+'\",\"SLA_Name\":\"'+$sla+'\",\"Assigned_Engineer_Name\":\"'+$escalate_Asignee+'\",\"Assigned_Engineer_Email\":\"'+$escalate_Assignee_mail+'\"},\"TicketInformation\":{\"UserLog\":\"'+$healix_notes+'\"}}'
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
        }

}
}
catch{
    $_
}