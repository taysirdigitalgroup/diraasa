package com.tdg.diraasa

/** Never turn an old queued alarm into a sound hours after its scheduled time. */
object AlarmDelivery {
    const val GRACE_MS=120000L
    fun due(at:Long,now:Long=System.currentTimeMillis()) = at>0 && now>=at-1000L && now-at<=GRACE_MS
}
