import com.tdg.diraasa.QuranAudioSequence
fun main(){
    val languages=listOf("ar","fr","en")
    val modes=languages+languages.flatMap{a->languages.filter{it!=a}.map{b->"$a-$b"}}+languages.flatMap{a->languages.filter{it!=a}.flatMap{b->languages.filter{it!=a&&it!=b}.map{c->"$a-$b-$c"}}}
    check(modes.size==15&&modes.toSet().size==15)
    for(mode in modes){
        val sequence=QuranAudioSequence.parse(mode)
        check(sequence.skipsUnavailable(true))
        check(sequence.skipsUnavailable(false)==(mode.split("-").size>1))
        val actual=mutableListOf<String>();var verse=1
        while(verse<=7){actual.add("$verse:${sequence.language}");if(sequence.advance())verse++}
        check(actual==(1..7).flatMap{v->mode.split("-").map{"$v:$it"}})
        check(sequence.language==mode.split("-").first())
    }
    for(invalid in listOf("","ar-ar","es","ar-fr-en-ar","ar-")){
        var rejected=false;try{QuranAudioSequence.parse(invalid)}catch(_:IllegalArgumentException){rejected=true};check(rejected)
    }
    println("OK: all 15 modes, verse-by-verse order, cycle reset, invalid modes rejected")
}
