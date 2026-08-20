import api from './api';

export type HrAssistantChatResponse = {
  requestId: string;
  answer: string;
  usedTools: string[];
};

export async function askHrAssistant(message: string): Promise<HrAssistantChatResponse> {
  const { data } = await api.post<HrAssistantChatResponse>('/v1/hr-assistant/chat', { message });
  return data;
}
