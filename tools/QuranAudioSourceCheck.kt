import com.tdg.diraasa.QuranAudioSource
fun main(){
    check(QuranAudioSource.filename(1,1)=="001001.mp3")
    check(QuranAudioSource.filename(114,6)=="114006.mp3")
    check(QuranAudioSource.url(2,0,"ar")=="https://raw.githubusercontent.com/taysirdigitalgroup/diraasa-quran-sounds/main/quran-hafs-ar/002000.mp3")
    check(QuranAudioSource.url(3,1,"fr").endsWith("/quran-hafs-fr/003001.mp3"))
    check(QuranAudioSource.url(114,6,"en").endsWith("/quran-hafs-en/114006.mp3"))
    for((chapter,verse,lang) in listOf(Triple(1,0,"ar"),Triple(9,0,"ar"),Triple(2,1,"es"),Triple(114,7,"en"))){
        var rejected=false;try{QuranAudioSource.url(chapter,verse,lang)}catch(_:IllegalArgumentException){rejected=true};check(rejected)
    }
    println("OK: native Hafs URLs, filenames, basmala exclusions and audio languages")
}
