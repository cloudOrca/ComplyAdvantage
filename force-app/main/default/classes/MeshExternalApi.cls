public class MeshExternalApi {
    public static String buildBaseUrl(Mesh_External_API__c api){
        return 'https://' + api.environment__c + '.' + api.region__c + '.mesh.complyadvantage.com/' + api.version__c;
    }

    public static String getToken(String endpoint, String realm, String username, String password){
        /*Mesh_External_API__c api = Mesh_External_API__c.getOrgDefaults();
        String baseUrl = MeshExternalApi.buildBaseUrl(api);
        String token = MeshExternalApi.getToken(baseUrl + '/token', api.realm__c, api.username__c, api.password__c);*/

        String tokenBody = 'username=' + EncodingUtil.urlEncode(username, 'UTF-8')
        + '&password=' + EncodingUtil.urlEncode(password, 'UTF-8')
        + '&realm=' + EncodingUtil.urlEncode(realm, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(tokenBody);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            System.debug('responseMap responseMap responseMap' + responseMap);
            return (String) responseMap.get('access_token');
        } else {
            System.debug('Error getting access token: ' + res.getBody());
            throw new CalloutException('Failed to obtain access token: ' + res.getStatus());
        }
    }

    public static HttpRequest buildRequest(String endpoint, String method, String token){
        Mesh_External_API__c api = Mesh_External_API__c.getOrgDefaults();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setMethod(method);
        req.setTimeOut(120000);
        return req;
    }
}