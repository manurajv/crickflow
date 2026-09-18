"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  createSeries,
  createSeriesClub,
  getSeriesDetail,
  getSeriesRegistrationIdentity,
  listActiveSeries,
  listSeriesAdmins,
  listSeriesCompetitions,
  addSeriesAdmin,
  proposeSeriesMatch,
  proposeSeriesTournament,
  reviewClubJoinRequest,
  reviewSeriesApproval,
  submitPlayerJoinRequest,
  submitSeriesRegistration,
  updateSeriesSettings,
} from "./repository";

export function useActiveSeries() {
  return useQuery({ queryKey: ["series", "active"], queryFn: () => listActiveSeries() });
}

export function useCreateSeries() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      name: string;
      description?: string;
      rulesText?: string;
      kind?: string;
      displayName?: string;
      logoUrl?: string;
      coverImageUrl?: string;
      settings?: Record<string, unknown>;
    }) => createSeries(input),
    onSuccess: () => client.invalidateQueries({ queryKey: ["series", "active"] }),
  });
}

export function useReviewSeriesApproval(seriesId: string) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: { approvalId: string; decision: "approved" | "rejected" }) =>
      reviewSeriesApproval(seriesId, input.approvalId, input.decision),
    onSuccess: () => client.invalidateQueries({ queryKey: ["series", seriesId] }),
  });
}

export function useReviewClubJoinRequest(seriesId: string) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      approvalId: string;
      decision: "approved" | "rejected";
      reason?: string;
    }) => reviewClubJoinRequest({ seriesId, ...input }),
    onSuccess: () => client.invalidateQueries({ queryKey: ["series", seriesId] }),
  });
}

export function useSeriesRegistrationIdentity(seriesId: string) {
  return useMutation({
    mutationFn: (registrationId: string) =>
      getSeriesRegistrationIdentity(seriesId, registrationId),
  });
}

export function useCreateSeriesClub(seriesId: string) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: { name: string; description?: string }) =>
      createSeriesClub({ seriesId, ...input }),
    onSuccess: () => client.invalidateQueries({ queryKey: ["series", seriesId] }),
  });
}

export function useUpdateSeriesSettings(seriesId: string) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (settings: Record<string, unknown>) =>
      updateSeriesSettings(seriesId, settings),
    onSuccess: () => client.invalidateQueries({ queryKey: ["series", seriesId] }),
  });
}

export function useJoinClub(seriesId: string) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: async (input: {
      clubId: string;
      fullName: string;
      crickFlowPlayerId?: string;
      phoneNumber?: string;
    }) => {
      const reg = await submitSeriesRegistration({
        seriesId,
        clubId: input.clubId,
        fullName: input.fullName,
        crickFlowPlayerId: input.crickFlowPlayerId,
        phoneNumber: input.phoneNumber,
      });
      await submitPlayerJoinRequest({
        seriesId,
        clubId: input.clubId,
        registrationId: reg.registrationId,
        displayName: input.fullName,
      });
    },
    onSuccess: () => client.invalidateQueries({ queryKey: ["series", seriesId] }),
  });
}

export function useProposeSeriesMatch(seriesId: string) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      clubAId: string;
      clubBId: string;
      title?: string;
      createMatchDraft?: boolean;
    }) => proposeSeriesMatch({ seriesId, createMatchDraft: true, ...input }),
    onSuccess: () => client.invalidateQueries({ queryKey: ["series", seriesId] }),
  });
}

export function useProposeSeriesTournament(seriesId: string) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: { tournamentId: string; title?: string; clubId?: string }) =>
      proposeSeriesTournament({ seriesId, ...input }),
    onSuccess: () => client.invalidateQueries({ queryKey: ["series", seriesId] }),
  });
}

export function useSeriesCompetitions(seriesId: string) {
  return useQuery({
    queryKey: ["series", seriesId, "competitions"],
    queryFn: () => listSeriesCompetitions(seriesId),
    enabled: Boolean(seriesId),
  });
}

export function useSeriesAdmins(seriesId: string) {
  return useQuery({
    queryKey: ["series", seriesId, "admins"],
    queryFn: () => listSeriesAdmins(seriesId),
    enabled: Boolean(seriesId),
  });
}

export function useAddSeriesAdmin(seriesId: string) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: { userId: string; displayName?: string }) =>
      addSeriesAdmin({ seriesId, ...input }),
    onSuccess: () => client.invalidateQueries({ queryKey: ["series", seriesId] }),
  });
}

export function useSeriesDetail(seriesId: string, userId?: string) {
  return useQuery({
    queryKey: ["series", seriesId, userId ?? "public"],
    queryFn: () => getSeriesDetail(seriesId, userId),
    enabled: Boolean(seriesId),
  });
}
