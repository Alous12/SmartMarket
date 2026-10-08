export type UserRole = 'user' | 'admin';

export interface User {
  user_id: number;
  name: string;
  last_name: string;
  email: string;
  role: UserRole;
  status: boolean;
  created_at: Date;
  created_by_user_id: number | null;
  updated_at: Date;
  updated_by_user_id: number | null;
}

export interface CreateUserInput {
  name: string;
  last_name: string;
  email: string;
  password: string;
}

export interface UpdateUserInput {
  name?: string;
  last_name?: string;
  email?: string;
  password?: string;
  status?: boolean;
}
