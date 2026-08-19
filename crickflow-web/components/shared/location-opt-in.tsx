"use client";

import { Button } from "@/components/ui/button";
import { useLocationStore } from "@/stores/location-store";

export function LocationOptIn() {
  const { consented, latitude, longitude, requestLocation, deny } = useLocationStore();
  return (
    <div className="flex flex-wrap items-center gap-2 text-sm">
      {consented && latitude != null ? (
        <>
          <span className="text-muted-foreground">
            Nearby ~30 km ({latitude.toFixed(2)}, {longitude?.toFixed(2)})
          </span>
          <Button size="sm" variant="outline" onClick={deny}>
            Clear location
          </Button>
        </>
      ) : (
        <Button size="sm" variant="outline" onClick={requestLocation}>
          Use my location
        </Button>
      )}
    </div>
  );
}
