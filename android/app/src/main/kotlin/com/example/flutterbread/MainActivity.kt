package com.example.flutterbread

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.initialization.InitializationStatus
import com.google.android.gms.ads.initialization.OnInitializationCompleteListener

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize Mobile Ads SDK
        MobileAds.initialize(this, OnInitializationCompleteListener { initializationStatus: InitializationStatus? ->
            // Ads SDK initialized, you can load ads now
        })
    }
}
