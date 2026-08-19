export function locationMatchesTextFilter(
  location: { country?: string; stateProvince?: string; city?: string },
  filter: { country?: string; stateProvince?: string; city?: string },
) {
  const country = filter.country?.trim() ?? "";
  const state = filter.stateProvince?.trim() ?? "";
  const city = filter.city?.trim() ?? "";
  if (!country && !state && !city) return true;
  if (country && !(location.country ?? "").toLowerCase().includes(country.toLowerCase())) {
    return false;
  }
  if (state && !(location.stateProvince ?? "").toLowerCase().includes(state.toLowerCase())) {
    return false;
  }
  if (city && !(location.city ?? "").toLowerCase().includes(city.toLowerCase())) {
    return false;
  }
  return true;
}

export function locationWritePayload(
  profileLocation?: {
    country?: string;
    stateProvince?: string;
    district?: string;
    city?: string;
    placeName?: string;
  } | null,
  coords?: { latitude: number; longitude: number } | null,
) {
  return {
    country: profileLocation?.country ?? "",
    stateProvince: profileLocation?.stateProvince ?? "",
    district: profileLocation?.district ?? "",
    city: profileLocation?.city ?? "",
    placeName: profileLocation?.placeName ?? "",
    ...(coords
      ? { latitude: coords.latitude, longitude: coords.longitude }
      : {}),
  };
}
