import '../lib/devotion/prayer_settings.dart';
void main(){
  assert(prayerMinuteValue('',17)==17);
  assert(prayerMinuteValue('١٥',0)==15);
  assert(prayerMinuteValue('-۵',0)==-5);
  final offsets=combinedPrayerOffsets({'adjustments':{'Fajr':'10','Dhuhr':'-5'}},defaultAzanLeads);
  assert(offsets['Fajr']==-35&&offsets['Dhuhr']==-20&&offsets['Maghrib']==0);
  final selected=prayerAzanLeads({'Fajr':0,'Dhuhr':30});
  assert(selected['Fajr']==0&&selected['Dhuhr']==30&&selected['Maghrib']==0&&selected['Isha']==15);
  assert(prayerAppliedOffsets({'adjustments':{'Dhuhr':'999'}})['Dhuhr']==120);
  print('OK : avances par défaut, avances personnalisées, chiffres arabes, valeur vide et calcul séparé des appels.');
}
