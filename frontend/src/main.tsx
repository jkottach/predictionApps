import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.tsx';
import './index.css';
import { GoogleOAuthProvider } from '@react-oauth/google';
import { tenant } from './config/tenant';

document.title = tenant.name;
const metaDescription = document.querySelector('meta[name="description"]');
if (metaDescription) {
  metaDescription.setAttribute('content', tenant.description);
}

const useAzureAuth = import.meta.env.VITE_USE_AZURE_AUTH === 'true';
const googleClientId = import.meta.env.VITE_GOOGLE_CLIENT_ID ?? '';

const app = <App />;

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    {useAzureAuth ? (
      app
    ) : googleClientId ? (
      <GoogleOAuthProvider clientId={googleClientId}>{app}</GoogleOAuthProvider>
    ) : (
      app
    )}
  </React.StrictMode>
);
