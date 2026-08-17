# Google Play Billing
-keep class com.android.vending.billing.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }

# Crashlytics: keep line numbers and source file names for readable stacks.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
