import com.tdg.diraasa.BackupMedia
import java.io.File
import java.nio.file.Files
fun main(){
    val temp=Files.createTempDirectory("diraasa-media-alias").toFile()
    try {
        val real=File(temp,"real/files").apply{mkdirs()}
        val alias=File(temp,"alias");Files.createSymbolicLink(alias.toPath(),real.toPath())
        val image=File(real,"author_photos/a.img").apply{parentFile!!.mkdirs();writeBytes(byteArrayOf(1,2,3))}
        for(root in listOf(real,alias))for(path in listOf(image.path,File(alias,"author_photos/a.img").path,image.toURI().toString())){
            val source=BackupMedia.resolve(root,path)?:error("Image ignored: $root / $path")
            check(source.kind=="author_photos" && source.file==image.canonicalFile && source.file.isFile)
        }
        check(BackupMedia.resolve(real,File(temp,"outside.img").path)==null)
        check(BackupMedia.resolve(real,File(real,"author_photos/../../outside.img").path)==null)
        check(BackupMedia.resolve(real,"asset:audio/adhan_1.m4a")==null)
        println("OK: media aliases, file URI, canonical root and traversal rejection")
    }finally{temp.deleteRecursively()}
}
