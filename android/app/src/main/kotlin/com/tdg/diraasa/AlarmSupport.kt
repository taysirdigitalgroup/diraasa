package com.tdg.diraasa

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

object AlarmSupport {
    fun background(c:Context)=Build.VERSION.SDK_INT<23||(c.getSystemService(Context.POWER_SERVICE) as PowerManager).isIgnoringBatteryOptimizations(c.packageName)
    fun audio(c:Context,value:String):String {
        if(!value.startsWith("asset:")) { check(File(value).isFile){"Audio introuvable"};return value }
        val name=value.removePrefix("asset:");require(name.startsWith("audio/")&&!name.contains(".."))
        val dst=File(c.filesDir,"bundled_audio/"+name.substringAfterLast('/'));dst.parentFile?.mkdirs()
        if(!dst.isFile)c.assets.open(name).use{input->dst.outputStream().use{input.copyTo(it)}}
        return dst.path
    }
    fun requestBackground(a:Activity){
        a.startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,Uri.parse("package:"+a.packageName)))
    }
    fun locate(a:Activity,result:MethodChannel.Result){
        if(Build.VERSION.SDK_INT>=23&&a.checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION)!=PackageManager.PERMISSION_GRANTED){
            a.requestPermissions(arrayOf(android.Manifest.permission.ACCESS_COARSE_LOCATION,android.Manifest.permission.ACCESS_FINE_LOCATION),8410)
            result.error("LOCATION_PERMISSION","Autorisez la localisation puis relancez la détection",null);return
        }
        val manager=a.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val fine=Build.VERSION.SDK_INT<23||a.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED
        val providers=if(fine)listOf(LocationManager.NETWORK_PROVIDER,LocationManager.GPS_PROVIDER)else listOf(LocationManager.NETWORK_PROVIDER)
        val provider=providers.firstOrNull{manager.isProviderEnabled(it)}
        if(provider==null){a.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS));result.error("LOCATION_OFF","Activez la localisation puis réessayez",null);return}
        val main=Handler(Looper.getMainLooper());var finished=false
        lateinit var listener:LocationListener
        val timeout=Runnable{if(!finished){finished=true;manager.removeUpdates(listener);result.error("LOCATION_TIMEOUT","Position indisponible ; réessayez à l’extérieur ou utilisez les coordonnées manuelles",null)}}
        listener=object:LocationListener{
            override fun onLocationChanged(location:Location){
                if(finished)return;finished=true;manager.removeUpdates(this);main.removeCallbacks(timeout)
                Thread{
                    var address="";var city="";var country=""
                    try{
                        @Suppress("DEPRECATION") val found=Geocoder(a,Locale.getDefault()).getFromLocation(location.latitude,location.longitude,1)?.firstOrNull()
                        if(found!=null){address=(0..found.maxAddressLineIndex).mapNotNull{found.getAddressLine(it)}.joinToString(", ");city=found.locality?:found.subAdminArea?:"";country=found.countryName?:""}
                    }catch(_:Exception){}
                    main.post{result.success(mapOf("latitude" to location.latitude,"longitude" to location.longitude,"address" to address,"city" to city,"country" to country,"accuracy" to location.accuracy.toDouble()))}
                }.start()
            }
            override fun onProviderEnabled(p:String){}
            override fun onProviderDisabled(p:String){}
            @Deprecated("Legacy callback") override fun onStatusChanged(p:String,s:Int,b:Bundle?){}
        }
        manager.requestLocationUpdates(provider,0L,0f,listener,Looper.getMainLooper());main.postDelayed(timeout,30000)
    }
}
