package com.tdg.diraasa

import android.app.Activity
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class DevotionNative(private val activity: Activity) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var audioResult: MethodChannel.Result? = null
    fun accepts(method: String) = method in setOf("applicationSettings","alarmTest","audioCatalog","backgroundSettings","detectLocation","devotionRead","devotionWrite","pickAzan","azanStatus","azanPermissions","azanExactSettings","azanSchedule","azanDisable","azanPreview","azanStop","remindersConfigure","devotionLaunch")
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val a = call.arguments as? Map<*,*> ?: emptyMap<Any,Any>()
        try {
            when (call.method) {
                "applicationSettings" -> {activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:"+activity.packageName)));result.success(true)}
                "alarmTest" -> {
                    check(AzanAlarms.exact(activity)&&AzanAlarms.notifications(activity)&&AlarmSupport.background(activity)){"Autorisez notifications, alarmes exactes et batterie sans restriction"}
                    val at=System.currentTimeMillis()+10000
                    val intent=Intent(activity,ZikrReminderReceiver::class.java).setAction("com.tdg.diraasa.TEST").putExtra("at",at).putExtra("audio",AlarmSupport.audio(activity,a["audio"]?.toString()?:"asset:audio/reminder.ogg"))
                    val pending=android.app.PendingIntent.getBroadcast(activity,8538,intent,android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
                    (activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager).setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pending)
                    result.success(true)
                }
                "audioCatalog" -> result.success(activity.assets.open("audio/catalog.json").bufferedReader().use{it.readText()})
                "backgroundSettings" -> {AlarmSupport.requestBackground(activity);result.success(true)}
                "detectLocation" -> AlarmSupport.locate(activity,result)

                "devotionLaunch" -> {
                    val intent=activity.intent
                    val target=intent?.getStringExtra("devotionTarget")
                    if(target==null)result.success(null)else{
                        val chain=intent.getBooleanExtra("devotionChain",false)
                        intent.removeExtra("devotionTarget");intent.removeExtra("devotionChain")
                        result.success(mapOf("id" to target,"chain" to chain))
                    }
                }
                "pickAzan" -> {
                    check(audioResult == null) { "Sélection déjà ouverte" }
                    audioResult = result
                    try { activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        type="audio/*"; addCategory(Intent.CATEGORY_OPENABLE)
                    },8402) } catch(e:Exception) { audioResult=null;throw e }
                }
                "azanStatus" -> result.success(AzanAlarms.status(activity))
                "azanPermissions" -> {
                    val allowed = Build.VERSION.SDK_INT < 33 || activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    if (!allowed && Build.VERSION.SDK_INT >= 33) activity.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),8403)
                    result.success(allowed)
                }
                "azanExactSettings" -> {
                    if(Build.VERSION.SDK_INT >= 31) activity.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,Uri.parse("package:"+activity.packageName)))
                    result.success(true)
                }
                "azanDisable" -> { AzanAlarms.disable(activity);result.success(true) }
                "azanStop" -> { activity.stopService(Intent(activity,AzanService::class.java));result.success(true) }
                "azanPreview" -> {
                    val path=AlarmSupport.audio(activity,a["audio"]?.toString() ?: "")
                    check(File(path).isFile) { "Audio manquant" }
                    AzanService.play(activity,path,"Diraasa · أذان");result.success(true)
                }
                else -> worker.execute {
                    try {
                        val value:Any? = when(call.method) {
                            "devotionRead" -> activity.getSharedPreferences("diraasa_devotion_v1",Context.MODE_PRIVATE).getString(a["key"].toString(),null)
                            "devotionWrite" -> {
                                check(activity.getSharedPreferences("diraasa_devotion_v1",Context.MODE_PRIVATE).edit().putString(a["key"].toString(),a["value"].toString()).commit())
                                true
                            }
                            "remindersConfigure" -> ZikrReminders.configure(activity,a["reminders"] as? List<*>?:emptyList<Any>())
                            "azanSchedule" -> AzanAlarms.configure(activity,a)
                            else -> throw IllegalArgumentException("Méthode inconnue")
                        }
                        main.post { result.success(value) }
                    }catch(e:Exception){ main.post { result.error("DEVOTION",e.message,null) } }
                }
            }
        }catch(e:Exception){ result.error("DEVOTION",e.message,null) }
    }
    fun activityResult(request: Int, code: Int, data: Intent?): Boolean {
        if(request!=8402)return false
        val result=audioResult;audioResult=null
        if(result==null)return true
        val uri=data?.data
        if(code!=Activity.RESULT_OK||uri==null){result.success(null);return true}
        worker.execute {
            var file:File?=null
            try {
                val folder=File(activity.filesDir,"azan_audio").apply{mkdirs()}
                val target=File(folder,UUID.randomUUID().toString()+".audio");file=target
                activity.contentResolver.openInputStream(uri)!!.use { input -> target.outputStream().use { output ->
                    val buffer=ByteArray(8192);var total=0
                    while(true){val n=input.read(buffer);if(n<0)break;total+=n;check(total<=30*1024*1024){"Audio trop volumineux (30 Mo max)"};output.write(buffer,0,n)}
                } }
                val reader=android.media.MediaMetadataRetriever()
                try{reader.setDataSource(target.path);check((reader.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()?:0)>0){"Audio invalide"}}finally{reader.release()}
                main.post{result.success(target.path)}
            }catch(e:Exception){file?.delete();main.post{result.error("AUDIO",e.message,null)}}
        }
        return true
    }
}
