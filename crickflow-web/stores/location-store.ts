import { create } from "zustand";

interface LocationState {
  consented: boolean;
  latitude?: number;
  longitude?: number;
  requestLocation: () => void;
  deny: () => void;
}

export const useLocationStore = create<LocationState>((set) => ({
  consented: false,
  requestLocation: () => {
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (pos) =>
        set({
          consented: true,
          latitude: pos.coords.latitude,
          longitude: pos.coords.longitude,
        }),
      () => set({ consented: false }),
    );
  },
  deny: () => set({ consented: false, latitude: undefined, longitude: undefined }),
}));
