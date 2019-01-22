public class PushRequestWrapper {
	
    @AuraEnabled
    public PackagePushRequest pushReq;
     
    @AuraEnabled
    //public List<PackagePushJob> pushReqJobs;
    public PackagePushJob pushReqJobs;
    
    @AuraEnabled
    //public List<PackagePushError> pushReqErrors; 
    public PackagePushError pushReqErrors; 
    
    @AuraEnabled
    //public List<PackageSubscriber> pushSubscribers;
    public PackageSubscriber pushSubscribers;
    
    @AuraEnabled
    public MetadataPackageVersion pushPkgVer;
    
    @AuraEnabled
    public MetadataPackage pushPkg;
    
	//public Map<String String> retData;
    /*
    @AuraEnabled
    Public Object jsonData;
    
    public PushRequestWrapper(List<PackagePushJob> pushJob){
    	retData.put('OrgName', (String)pushReq.OrgName);
        retData.put('MajorVersion', pushPkgVer.MajorVersion);
        for(PackgePushJob pj: pushJobReqs){
            retData.put('sdfdsaf', pj.something);
        }

        jsonData = JSON.serialize(retData);
    }
    */
}