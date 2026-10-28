package com.tdg.diraasa

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.ExecutorService

/** File picker and Drive jobs; all archive/database work shares the notes executor. */
class BackupNative(private val activity:Activity,private val worker:ExecutorService) {
    private val drive=DriveBackup(activity,worker)
    private var pending:MethodChannel.Result?=null
    private var exportFile:File?=null
    private var staged:Pair<File,JSONObject>?=null
    fun accepts(method:String)=method.startsWith("backup")||method.startsWith("drive")
    private fun success(result:MethodChannel.Result,value:Any?){activity.runOnUiThread{result.success(value)}}
    private fun fail(result:MethodChannel.Result,e:Exception){activity.runOnUiThread{result.error("BACKUP",e.message,null)}}
    private fun background(result:MethodChannel.Result,job:()->Any?){worker.execute{try{success(result,job())}catch(e:Exception){fail(result,e)}}}
    private fun stage(source:File):Map<String,Any>{
        staged?.first?.deleteRecursively();staged=null
        val directory=File(activity.cacheDir,"backup-stage-${UUID.randomUUID()}")
        val data=BackupArchive.read(source,directory)
        try{BackupStore.validate(data,directory)}catch(e:Exception){directory.deleteRecursively();throw e}
        staged=directory to data
        return BackupStore.summary(data)
    }
    fun handle(call:MethodCall,result:MethodChannel.Result){
        val args=call.arguments as? Map<*,*>?:emptyMap<Any,Any>()
        try{when(call.method){
            "backupExportLocal"->{
                check(pending==null){"Sélection déjà ouverte"};pending=result
                worker.execute{try{
                    val file=File(activity.cacheDir,"Diraasa_${System.currentTimeMillis()}.diraasa.zip")
                    synchronized(PrayerSyncWorker.lock){BackupStore.snapshot(activity,file)}
                    exportFile=file
                    activity.runOnUiThread{try{activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply{
                        type="application/zip";addCategory(Intent.CATEGORY_OPENABLE);putExtra(Intent.EXTRA_TITLE,file.name)
                    },8450)}catch(e:Exception){pending=null;file.delete();exportFile=null;result.error("BACKUP",e.message,null)}}
                }catch(e:Exception){pending=null;fail(result,e)}}
            }
            "backupPrepareLocal"->{check(pending==null);pending=result;activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply{type="*/*";addCategory(Intent.CATEGORY_OPENABLE)},8451)}
            "backupApply"->background(result){val (dir,data)=staged?:error("Choisissez une sauvegarde")
                synchronized(PrayerSyncWorker.lock){BackupStore.restore(activity,data,dir)}.also{dir.deleteRecursively();staged=null}
            }
            "backupCancel"->background(result){staged?.first?.deleteRecursively();staged=null;true}
            "backupRecoveryList"->background(result){File(activity.filesDir,"recovery_backups").listFiles()?.filter{it.isFile}?.sortedByDescending{it.lastModified()}?.map{mapOf("id" to it.name,"name" to it.name,"size" to it.length(),"createdAt" to it.lastModified())}?:emptyList<Any>()}
            "backupPrepareRecovery"->background(result){val name=args["id"]?.toString()?:"";require(Regex("Diraasa_avant_restauration_[0-9]+\\.diraasa\\.zip").matches(name));stage(File(activity.filesDir,"recovery_backups/$name"))}
            "driveStatus"->result.success(drive.status())
            "driveConnect"->drive.connect(result)
            "driveDisconnect"->drive.disconnect(result)
            "driveDeleteAccount"->drive.deleteAccount(result)
            "driveList"->drive.authorized(result){token->drive.list(token)}
            "driveOpenFolder"->drive.authorized(result){token->val id=drive.folder(token);mapOf("url" to "https://drive.google.com/drive/folders/$id?authuser=${Uri.encode(drive.email())}")}
            "driveBackup"->drive.authorized(result){token->val file=File(activity.cacheDir,"Diraasa_${System.currentTimeMillis()}.diraasa.zip")
                try{synchronized(PrayerSyncWorker.lock){BackupStore.snapshot(activity,file)};drive.upload(token,file)}finally{file.delete()}}
            "drivePrepare"->drive.authorized(result){token->val file=File(activity.cacheDir,"drive-incoming-${UUID.randomUUID()}.zip")
                try{drive.download(token,args["id"]?.toString()?:"",file);stage(file)}finally{file.delete()}}
            else->result.notImplemented()
        }}catch(e:Exception){if(pending===result)pending=null;result.error("BACKUP",e.message,null)}
    }
    fun activityResult(code:Int,status:Int,data:Intent?):Boolean {
        if(drive.activityResult(code,status,data))return true
        if(code !in setOf(8450,8451))return false
        val result=pending?:return true;pending=null
        val uri=data?.data
        if(status!=Activity.RESULT_OK||uri==null){exportFile?.delete();exportFile=null;result.success(null);return true}
        if(code==8450){val file=exportFile;exportFile=null;background(result){try{
            require(file!=null);activity.contentResolver.openOutputStream(uri,"wt")!!.use{out->file.inputStream().use{it.copyTo(out)}};mapOf("name" to file.name)
        }finally{file?.delete()}}}
        else background(result){val file=File(activity.cacheDir,"local-incoming-${UUID.randomUUID()}.zip")
            try{activity.contentResolver.openInputStream(uri)!!.use{BackupArchive.copyLimited(it,file,BackupArchive.MAX_BYTES)};stage(file)}finally{file.delete()}}
        return true
    }
}
