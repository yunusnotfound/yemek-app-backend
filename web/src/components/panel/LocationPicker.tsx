"use client";

import { useEffect, useRef } from "react";
// (ref güncellemesi render sırasında değil, effect içinde yapılır)
import mapboxgl from "mapbox-gl";
import "mapbox-gl/dist/mapbox-gl.css";
import { MAPBOX_TOKEN } from "@/lib/config";

const DEFAULT_CENTER: [number, number] = [28.9784, 41.0082]; // İstanbul [lng, lat]

/**
 * Harita üzerinde tıklayarak/sürükleyerek konum seçtirir.
 * Mapbox token yoksa null döner; üst bileşen elle lat/lng girişine düşer.
 */
export function LocationPicker({
  lat,
  lng,
  onChange,
}: {
  lat?: number;
  lng?: number;
  onChange: (lat: number, lng: number) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<mapboxgl.Map | null>(null);
  const markerRef = useRef<mapboxgl.Marker | null>(null);
  const onChangeRef = useRef(onChange);
  useEffect(() => {
    onChangeRef.current = onChange;
  });

  useEffect(() => {
    if (!MAPBOX_TOKEN || !containerRef.current || mapRef.current) return;

    mapboxgl.accessToken = MAPBOX_TOKEN;
    const center: [number, number] =
      lat != null && lng != null ? [lng, lat] : DEFAULT_CENTER;

    const map = new mapboxgl.Map({
      container: containerRef.current,
      style: "mapbox://styles/mapbox/streets-v12",
      center,
      zoom: 12,
    });
    map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), "top-right");
    mapRef.current = map;

    const marker = new mapboxgl.Marker({ draggable: true, color: "#16a34a" })
      .setLngLat(center)
      .addTo(map);
    markerRef.current = marker;

    marker.on("dragend", () => {
      const p = marker.getLngLat();
      onChangeRef.current(p.lat, p.lng);
    });
    map.on("click", (e) => {
      marker.setLngLat(e.lngLat);
      onChangeRef.current(e.lngLat.lat, e.lngLat.lng);
    });

    return () => {
      map.remove();
      mapRef.current = null;
      markerRef.current = null;
    };
    // İlk yüklemede bir kez kurulur; konum güncellemeleri aşağıdaki effect'te.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Dışarıdan lat/lng gelirse (ör. düzenlemede ön doldurma) marker'ı taşı.
  useEffect(() => {
    if (markerRef.current && mapRef.current && lat != null && lng != null) {
      markerRef.current.setLngLat([lng, lat]);
      mapRef.current.setCenter([lng, lat]);
    }
  }, [lat, lng]);

  if (!MAPBOX_TOKEN) return null;

  return (
    <div
      ref={containerRef}
      className="h-64 w-full overflow-hidden rounded-xl border border-slate-300"
    />
  );
}
