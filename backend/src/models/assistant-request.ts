export type AssistantRequestStatus =
  | 'RECEIVED'
  | 'PROCESSING'
  | 'COMPLETED'
  | 'FAILED';

export interface AssistantRequest {
  request_id: number;
  user_id: number;
  prompt: string;
  status: AssistantRequestStatus;
  created_at: Date;
  updated_at: Date;
}
