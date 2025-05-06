//
//  LocationManager.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        print("[LocationManager] Requesting location authorization...")
        manager.requestWhenInUseAuthorization()
        // ⛔️ Do NOT start updating location here
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("[LocationManager] Location authorized.")
            manager.startUpdatingLocation() // ✅ Start here when authorized

        case .denied, .restricted:
            print("[LocationManager] Location access denied or restricted.")

        case .notDetermined:
            print("[LocationManager] Authorization not determined. Requesting again...")
            manager.requestWhenInUseAuthorization()

        @unknown default:
            print("[LocationManager] Unknown authorization status: \(manager.authorizationStatus.rawValue)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("[LocationManager] Updated location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        } else {
            print("[LocationManager] Received update with no available locations.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationManager] Failed to update location: \(error.localizedDescription)")
    }
}
