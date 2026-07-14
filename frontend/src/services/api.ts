import axios from 'axios';
import { getToken } from '../utils/storage';
import { handleSessionFailure, isSessionFailure } from '../utils/sessionFailure';

const apiBaseUrl = (import.meta.env.VITE_API_URL ?? '/api').replace(/\/$/, '');

const api = axios.create({
  baseURL: apiBaseUrl,
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use((config) => {
  const t = getToken();
  if (t) {
    config.headers.Authorization = `Bearer ${t}`;
  }
  return config;
});

api.interceptors.response.use(
  (r) => r,
  (err) => {
    if (isSessionFailure(err)) {
      handleSessionFailure();
    }
    return Promise.reject(err);
  }
);

export default api;
