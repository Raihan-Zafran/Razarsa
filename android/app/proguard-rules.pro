# flutter_local_notifications menyimpan jadwal lewat Gson (refleksi). Tanpa aturan ini R8 membuang
# informasi tipe dan notifikasi terjadwal gagal di build rilis ("Missing type parameter").
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
