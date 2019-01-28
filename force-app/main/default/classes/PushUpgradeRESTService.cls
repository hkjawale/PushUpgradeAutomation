/* Salesforce TrailheaDX - Automate Release Process via Package and Deploy APIs 
 * Push Upgrade API 
 * Author - Hemant Jawale 
 * Customers will send request to this custom REST end point to submit a package upgrade request 
 */
 
//Mark this class as a custom REST endpoint 
@RestResource(urlMapping='/PushUpgrade/*') 
global with sharing class PushUpgradeRESTService {
	
    //The return message string 
    public static String result; 
    
/*
This function is accssible via the REST POST call  
The class accepts the Org ID, the package name, the desired version 
to which the customer wants to upgrade and the desired date/time of the upgrade
*/  
@HttpPost
    global static String CreatePushRequest(String orgId, String desiredVersion, String packageName, DateTime scheduledStartDate ) {
        	
        	/* MetadataPackage object stores the information of packages created in the org
        	 * Retrieve the package the push request is requested for 
			 */
        	System.debug('the datetime input is: ' + scheduledStartDate);
            MetadataPackage pkg = [SELECT Id, Name from MetadataPackage WHERE Name =: packageName];
        	
        	//Get integer values of the version numbers 
            Integer desiredMajor = Integer.valueOf(desiredversion.charAt(0)) - 48;
            System.debug('Major: '+ desiredMajor);
            Integer desiredMinor = Integer.valueOf(desiredversion.charAt(2)) - 48;
            System.debug('Minor: '+ desiredMinor);
            Integer desiredPatch = Integer.valueOf(desiredversion.charAt(4)) - 48;
            System.debug('Patch: '+ desiredPatch);
			
        	/* MetadataPackageVersion object stores the information about all the versions of a packages created in the org
        	 * Retrieve the package version the push request is requested for 
			 */
        	MetadataPackageVersion desiredMetadataPkgVer = [SELECT MetadataPackageId, MajorVersion, MinorVersion, PatchVersion from MetadataPackageVersion WHERE ReleaseState = 'Released'
                                                           AND MajorVersion =: desiredMajor AND MinorVersion =: desiredMinor AND PatchVersion =: desiredPatch] ;

        	
        	//Retrieve the latest package version for the requested package 
        	List<MetadataPackageVersion> currentPkgVersion = [SELECT MetadataPackageId, MajorVersion, MinorVersion, PatchVersion from MetadataPackageVersion 
                                                               WHERE ReleaseState = 'Released' AND MetadataPackageId =: pkg.id 
                                                               Order by MajorVersion DESC, MinorVersion DESC, PatchVersion DESC] ;
        	  	
        	/* PackageSubscriber object stores the information about all the subscriber Orgs 
        	 * that have a version of the package installed   
        	 * Retrieve the package subscriber record corresponding to the customer's OrgId 
			 */
        	PackageSubscriber subscriberOrg = new PackageSubscriber();
            subscriberOrg = [SELECT MetadataPackageVersionId, OrgKey, OrgStatus, OrgName, OrgType FROM PackageSubscriber WHERE OrgKey =: orgId ]; 
            system.debug('The Subscriber Org Name is: ' + subscriberOrg.OrgName); 
        	
        	//Retrieve the package version the subscribe org is on 
        	MetadataPackageVersion subscriberPkgVersion = [SELECT MetadataPackageId, MajorVersion, MinorVersion, PatchVersion from MetadataPackageVersion 
                                                           WHERE ReleaseState = 'Released' AND Id =: subscriberOrg.MetadataPackageVersionId] ;
        	
        	//Compare the latest metadatapackage version of the package with the package version the subscriber org is on 
            if(subscriberPkgVersion != currentPkgVersion[0]) {
                
                //Check if the customer is requesting a version that has not been created yet 
                if(desiredMajor >  currentPkgVersion[0].MajorVersion) {
                    return ('That Version of the package does not exist. Please try another version');
                }
                else if(desiredMajor == currentPkgVersion[0].MajorVersion && desiredMinor > currentPkgVersion[0].MinorVersion) {
                    return ('That Version of the package does not exist. Please try another version');
                }  
                else if(desiredMajor == currentPkgVersion[0].MajorVersion && desiredMinor == currentPkgVersion[0].MinorVersion && desiredPatch > currentPkgVersion[0].PatchVersion) {
                    return ('That Version of the package does not exist. Please try another version');
                }
                
                //Check if the customer is requesting to upgrade to a lower version of the package 
                else if(desiredMajor < subscriberPkgVersion.MajorVersion) {
                    return ('You cannot upgrade to a lower version of the package. Please try another version');    
                } 
                else if(desiredMajor == subscriberPkgVersion.MajorVersion && desiredMinor < subscriberPkgVersion.MinorVersion) {
                    return ('You cannot upgrade to a lower version of the package. Please try another version');    
                }    
                else if(desiredMajor == subscriberPkgVersion.MajorVersion && desiredMinor == subscriberPkgVersion.MinorVersion && desiredPatch < subscriberPkgVersion.PatchVersion) {
                    return ('You cannot upgrade to a lower version of the package. Please try another version');
                }
                
                else {
                        //This means the subscriber is eligible for a push upgrade patch version 
                        
               			//Authentication parameters for the REST API calls 
                        String clientId = 'xxxyyyzzz';
                        String clientSecret = '999000';
                        String username = 'xxxxx@yyy.com';
                        String password = 'xxx';
                        String reqbody = 'grant_type=password&client_id='+clientId+'&client_secret='+clientSecret+'&username='+username+'&password='+password;
					
                        System.debug('req body: '+reqbody);
                    	//Authenticate using password method and get the session token 
                        Http httpauth = new Http();
                        HttpRequest reqauth = new HttpRequest();
                        System.debug('base url is: ' + System.URL.getSalesforceBaseURL().toExternalForm());
                        reqauth.setEndpoint(System.URL.getSalesforceBaseURL().toExternalForm() +'/services/oauth2/token'); 
                        reqauth.setBody(reqbody);
                        reqauth.setMethod('POST');
                        reqauth.setHeader('Content-Type','application/x-www-form-urlencoded');
                        HttpResponse resauth = httpauth.send(reqauth);
                    
                    	//OAuth2 is a wrapper apex class to store token and other result information 
                        OAuth2 objAuthenticationInfo = (OAuth2)JSON.deserialize(resauth.getbody(), OAuth2.class);
						
                    	//Proceed if we get an access token 
                        if(objAuthenticationInfo.access_token != null) {
                              
                            System.debug('The token is: ' + objAuthenticationInfo.access_token);
					    	
                        	//Setup all the variables for preparing a push request 
                            Time scheduleTime;
                            DateTime ScheduledStartDateTime;
                                       
                        	/* Send an http request to create a PushRequest 
                        	 * The endpoint is /services/data/v40.0/sobjects/packagepushrequest/
                        	 * Send the desired uprade package version id and the schedule start time  
                        	 * If the uprgrade needs to happen immediately, schedule start time should be null
                        	 * The response will be the newly create pushrequest ID 
                        	 * PushRequest gets created with a status "created"
                        	 */
							
                            Http httpcreatepush = new Http();
                            HttpRequest reqcreatepush = new HttpRequest();
                            reqcreatepush.setEndpoint(System.URL.getSalesforceBaseURL().toExternalForm()+'/services/data/v40.0/sobjects/packagepushrequest/');
                            reqcreatepush.setMethod('POST');
                            reqcreatepush.setHeader('Content-Type', 'application/json');
                            reqcreatepush.setHeader('Authorization','Bearer '+objAuthenticationInfo.access_token);
                            //PushRequestAPI is the wrapper apex class to store pushrequest call data 
                            
                            PushRequestAPI pr = new PushRequestAPI();
                            pr.ScheduledStartTime = scheduledStartDate;
                            pr.PackageVersionId = String.valueOf(desiredMetadataPkgVer.Id);
                            String jsonBody = json.serialize(pr);
                            String jsonBodyFinal = jsonBody.remove('.000Z');
                            System.debug('json body is check date here: ' + jsonBodyFinal);      	
                            reqcreatepush.setBody(jsonBodyFinal);
                        
                            HttpResponse rescreatepush = httpcreatepush.send(reqcreatepush);
                            System.debug('Result string is: ' + rescreatepush.getBody());
                            
                            /* Parse the response to get the newly created PushRequest ID 
                             */  
                            
                            String pushReqId;
                            JSONParser parser = JSON.createParser(rescreatepush.getBody());
                            while (parser.nextToken() != null) {
                            if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'id')) {
                                            // Get the value
                                            parser.nextToken();
                                            pushReqId = parser.getText();
                                            break;
                                }
                            }
                        
                            System.debug('req id is ' + pushReqId);
                            
                            /* Send an http request to create a PackagePushJob for uprading a particular subscriber Org 
                        	 * The endpoint is /services/data/v40.0/sobjects/packagepushjob/
                        	 * Send the prevoulsly created package version id and the subscriber org id 
                        	 */ 
                            
                            Http httpjob = new Http();
                            HttpRequest requestjob = new HttpRequest();
                            requestjob.setEndpoint(System.URL.getSalesforceBaseURL().toExternalForm() + '/services/data/v40.0/sobjects/packagepushjob/');
                            requestjob.setMethod('POST');
                            requestjob.setHeader('Content-Type', 'application/json');
                            requestjob.setHeader('Authorization','Bearer '+objAuthenticationInfo.access_token);
                            //PushRequestAPI is the wrapper apex class to store pushrequest call data
                            PushJobAPI pj = new PushJobAPI(); 
                            pj.PackagePushRequestId = pushReqId; 
                            pj.SubscriberOrganizationKey = subscriberOrg.OrgKey;
                            String jsonBodyJob = json.serialize(pj);
                            System.debug('json body for job is: ' + jsonBodyJob);
                            requestjob.setBody(jsonBodyJob); 
                            
                            
                            HttpResponse responsejob = httpjob.send(requestjob);
                            System.debug('Result string job: ' + responsejob.getBody());		
							
                            /* If ScheduledStartTime was mentioned, the push initiates at that time 
                             * Regardless, to initaite the PushRequest with the pushjob, send a patch call
                        	 * Update the PushRequest status to "Pending" to initate the push
                        	 * The endpoint is /services/data/v38.0/sobjects/packagepushrequest/ODV...(The PushRequestID)
                        	 */   
                                System.debug('scheduledStartDate: ' + scheduledStartDate);
                                System.debug('todays date: ' +  Date.today());
                                                               Http httppush = new Http();
                            
                            HttpRequest requestpush = new HttpRequest();
                            requestpush.setEndpoint(System.URL.getSalesforceBaseURL().toExternalForm() + '/services/data/v40.0/sobjects/packagepushrequest/' + pushReqId + '?_HttpMethod=PATCH');
                            System.debug('end point patch : ' + requestpush.getEndpoint());
                            requestpush.setMethod('POST');
                            //requestpush.setHeader('X-HTTP-Method-Override','PATCH');
                            requestpush.setHeader('Content-Type', 'application/json');
                            requestpush.setHeader('Authorization','Bearer '+objAuthenticationInfo.access_token);
                            PushInitiateAPI pi = new PushInitiateAPI();
                            pi.Status = 'Pending'; 
                            String jsonBodyPush = json.serialize(pi);
                            System.debug('json body for job is: ' + jsonBodyPush);
                            requestpush.setBody(jsonBodyPush); 
                            HttpResponse responsepush = httppush.send(requestpush);
                            System.debug('Result string job: ' + responsepush.getBody());	
                            
                            
                            result = ('The Push Request was created!');                     
                            return result; 
                        }
                }
                	
            }
            else {
                
                    result = 'You are already on the latest version'; 
                    return result; 
            }     
			return result; 
    }   	    
}
