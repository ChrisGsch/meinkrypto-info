import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import CryptoSite from "../components/CryptoSite";
import "../app/globals.css";

const root = document.getElementById("root");

if (!root) {
  throw new Error("Root element not found.");
}

createRoot(root).render(
  <StrictMode>
    <CryptoSite />
  </StrictMode>,
);
