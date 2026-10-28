package com.tdg.diraasa

import android.accounts.Account
import android.app.Activity
import android.content.Intent
import android.content.MutableContextWrapper
import androidx.credentials.*
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.Scope
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.ExecutorService

/** Firebase authenticates; AuthorizationClient separately grants drive.file access. */
class DriveBackup(private val activity:Activity,private val worker:ExecutorService){
    private val scope="https://www.googleapis.com/auth/drive.file"
    private var pending:MethodChannel.Result?=null
    private var operation:((String)->Any?)?=null
    private fun configured()=FirebaseApp.getApps(activity).isNotEmpty() && activity.resources.getIdentifier("default_web_client_id","string",activity.packageName)!=0
    private fun auth()=FirebaseAuth.getInstance()
    fun email()=if(configured())auth().currentUser?.email?:"" else ""
    fun status():Map<String,Any> = mapOf("configured" to configured(),"email" to email(),"connected" to email().isNotBlank())
    private fun error(result:MethodChannel.Result,e:Exception){pending=null;operation=null;activity.runOnUiThread{result.error("DRIVE",e.message,null)}}
    fun connect(result:MethodChannel.Result){
        check(configured()){"Ajoutez google-services.json et activez Google dans Firebase Authentication (guide inclus)."}
        check(pending==null){"Opération Drive déjà en cours"};pending=result
        val id=activity.getString(activity.resources.getIdentifier("default_web_client_id","string",activity.packageName))
        val option=GetSignInWithGoogleOption.Builder(id).build()
        val request=GetCredentialRequest.Builder().addCredentialOption(option).build()
        val channelResult=result
        CredentialManager.create(activity).getCredentialAsync(MutableContextWrapper(activity),request,null,
            androidx.core.content.ContextCompat.getMainExecutor(activity),object:CredentialManagerCallback<GetCredentialResponse,GetCredentialException>{
                override fun onResult(result:GetCredentialResponse){try{
                    val credential=GoogleIdTokenCredential.createFrom(result.credential.data)
                    auth().signInWithCredential(GoogleAuthProvider.getCredential(credential.idToken,null))
                        .addOnSuccessListener{pending=null;channelResult.success(status())}
                        .addOnFailureListener{error(channelResult,it)}
                }catch(e:Exception){error(channelResult,e)}}
                override fun onError(e:GetCredentialException){error(channelResult,e)}
            })
    }
    fun disconnect(result:MethodChannel.Result){
        check(pending==null){"Opération Drive en cours"}
        if(configured())auth().signOut()
        val channelResult=result
        CredentialManager.create(activity).clearCredentialStateAsync(ClearCredentialStateRequest(),null,
            androidx.core.content.ContextCompat.getMainExecutor(activity),object:CredentialManagerCallback<Void?,androidx.credentials.exceptions.ClearCredentialException>{
                override fun onResult(result:Void?){channelResult.success(status())}
                override fun onError(e:androidx.credentials.exceptions.ClearCredentialException){channelResult.success(status())}
            })
    }
    fun deleteAccount(result:MethodChannel.Result){
        check(pending==null);val user=if(configured())auth().currentUser else null
        if(user==null){result.success(status());return}
        pending=result
        user.delete().addOnSuccessListener{pending=null;disconnect(result)}.addOnFailureListener{error(result,it)}
    }
    fun authorized(result:MethodChannel.Result,job:(String)->Any?){
        check(configured()&&email().isNotBlank()){"Connectez votre compte Google"}
        check(pending==null){"Opération Drive déjà en cours"};pending=result;operation=job
        val request=AuthorizationRequest.builder().setAccount(Account(email(),"com.google"))
            .setRequestedScopes(listOf(Scope(scope))).build()
        Identity.getAuthorizationClient(activity).authorize(request).addOnSuccessListener{response->
            try{if(response.hasResolution())activity.startIntentSenderForResult(response.pendingIntent!!.intentSender,8452,null,0,0,0)
                else run(response.accessToken?:error("Autorisation Drive absente"))
            }catch(e:Exception){error(result,e)}
        }.addOnFailureListener{error(result,it)}
    }
    private fun run(token:String){val result=pending?:return;val job=operation?:return
        worker.execute{try{val value=job(token);activity.runOnUiThread{pending=null;operation=null;result.success(value)}}catch(e:Exception){error(result,e)}}
    }
    fun activityResult(code:Int,status:Int,data:Intent?):Boolean {
        if(code!=8452)return false
        val result=pending?:return true
        try{check(status==Activity.RESULT_OK&&data!=null){"Autorisation Drive annulée"}
            val response=Identity.getAuthorizationClient(activity).getAuthorizationResultFromIntent(data)
            run(response.accessToken?:error("Autorisation Drive absente"))
        }catch(e:Exception){error(result,e)};return true
    }
    private fun enc(value:String)=URLEncoder.encode(value,"UTF-8")
    private fun connection(token:String,url:String,method:String="GET"):HttpURLConnection {
        require(URL(url).protocol=="https"&&URL(url).host=="www.googleapis.com")
        return (URL(url).openConnection() as HttpURLConnection).apply{
            requestMethod=method;connectTimeout=20000;readTimeout=60000;instanceFollowRedirects=false
            setRequestProperty("Authorization","Bearer $token")
        }
    }
    private fun checkResponse(c:HttpURLConnection){val code=c.responseCode
        check(code in 200..299){when(code){401->"Session Drive expirée : réessayez ou reconnectez-vous";403->"Accès Drive refusé : vérifiez autorisation, API activée et espace disponible";404->"Sauvegarde ou dossier Drive introuvable";else->"Échec Drive (HTTP $code)"}}
    }
    private fun json(token:String,url:String,body:JSONObject?=null):JSONObject {
        val c=connection(token,url,if(body==null)"GET" else "POST")
        try{if(body!=null){c.doOutput=true;c.setRequestProperty("Content-Type","application/json; charset=UTF-8");c.outputStream.use{it.write(body.toString().toByteArray(Charsets.UTF_8))}}
            checkResponse(c);return JSONObject(c.inputStream.bufferedReader().use{it.readText()})
        }finally{c.disconnect()}
    }
    fun folder(token:String):String {
        val q="trashed=false and mimeType='application/vnd.google-apps.folder' and appProperties has { key='diraasaBackupFolder' and value='v1' }"
        val response=json(token,"https://www.googleapis.com/drive/v3/files?q=${enc(q)}&fields=files(id)&pageSize=100")
        val files=response.getJSONArray("files")
        if(files.length()>0)return files.getJSONObject(0).getString("id")
        return json(token,"https://www.googleapis.com/drive/v3/files?fields=id",JSONObject().put("name","Diraasa — Sauvegardes").put("mimeType","application/vnd.google-apps.folder").put("appProperties",JSONObject().put("diraasaBackupFolder","v1"))).getString("id")
    }
    fun list(token:String):List<Map<String,Any>> {
        val id=folder(token);val q="'$id' in parents and trashed=false and appProperties has { key='diraasaBackup' and value='v1' }"
        val rows=mutableListOf<Map<String,Any>>();var page=""
        do{val response=json(token,"https://www.googleapis.com/drive/v3/files?q=${enc(q)}&fields=nextPageToken,files(id,name,size,createdTime)&orderBy=createdTime%20desc&pageSize=100${if(page.isBlank())"" else "&pageToken=${enc(page)}"}")
            val files=response.getJSONArray("files");for(i in 0 until files.length()){val f=files.getJSONObject(i);rows.add(mapOf("id" to f.getString("id"),"name" to f.getString("name"),"size" to f.optString("size","0"),"createdTime" to f.optString("createdTime")))}
            page=response.optString("nextPageToken")
        }while(page.isNotBlank());return rows
    }
    fun upload(token:String,file:File):Map<String,String> {
        val meta=JSONObject().put("name",file.name).put("parents",JSONArray().put(folder(token))).put("appProperties",JSONObject().put("diraasaBackup","v1"))
        val start=connection(token,"https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,name","POST")
        val location:String
        try{start.doOutput=true;start.setRequestProperty("Content-Type","application/json; charset=UTF-8");start.setRequestProperty("X-Upload-Content-Type","application/zip");start.setRequestProperty("X-Upload-Content-Length",file.length().toString())
            start.outputStream.use{it.write(meta.toString().toByteArray(Charsets.UTF_8))};checkResponse(start);location=start.getHeaderField("Location")?:error("Session d’envoi absente")
        }finally{start.disconnect()}
        val upload=connection(token,location,"PUT")
        try{upload.doOutput=true;upload.setFixedLengthStreamingMode(file.length());upload.setRequestProperty("Content-Type","application/zip")
            file.inputStream().use{input->upload.outputStream.use{input.copyTo(it)}};checkResponse(upload)
            val row=JSONObject(upload.inputStream.bufferedReader().use{it.readText()});return mapOf("id" to row.getString("id"),"name" to row.getString("name"))
        }finally{upload.disconnect()}
    }
    fun download(token:String,id:String,target:File){
        require(Regex("[a-zA-Z0-9_-]+").matches(id))
        val f=json(token,"https://www.googleapis.com/drive/v3/files/$id?fields=id,parents,size,appProperties")
        require(f.optJSONObject("appProperties")?.optString("diraasaBackup")=="v1"){"Ce fichier n’est pas une sauvegarde Diraasa"}
        val parents=f.getJSONArray("parents");val folder=folder(token)
        require((0 until parents.length()).any{parents.getString(it)==folder})
        require(f.getString("size").toLong()<=BackupArchive.MAX_BYTES)
        val c=connection(token,"https://www.googleapis.com/drive/v3/files/$id?alt=media")
        try{checkResponse(c);c.inputStream.use{BackupArchive.copyLimited(it,target,BackupArchive.MAX_BYTES)}}finally{c.disconnect()}
    }
}
