/* ============================================================
   AUDITCV — main.js
   Global utilities: Supabase client, auth helpers, toasts
   ============================================================ */

// ── Supabase Config (substitua pelas suas credenciais) ──────
const SUPABASE_URL = 'https://SEU_PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'SUA_ANON_KEY';

// Carrega Supabase do CDN (inserido em cada HTML)
const { createClient } = supabase;
const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ── Claude / Anthropic API Key ──────────────────────────────
const CLAUDE_KEY = 'SUA_ANTHROPIC_KEY'; // nunca expor em produção real

// ── Toast ───────────────────────────────────────────────────
function toast(msg, type = 'info', duration = 4000) {
  let container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    document.body.appendChild(container);
  }
  const t = document.createElement('div');
  t.className = `toast toast-${type}`;
  const icons = { success: '✅', error: '❌', info: '💡' };
  t.innerHTML = `<span>${icons[type] || '💡'}</span><span>${msg}</span>`;
  container.appendChild(t);
  setTimeout(() => t.remove(), duration);
}

// ── Auth helpers ─────────────────────────────────────────────
async function getSession() {
  const { data } = await sb.auth.getSession();
  return data.session;
}

async function getUser() {
  const { data } = await sb.auth.getUser();
  return data.user;
}

async function requireAuth(redirectTo = 'login.html') {
  const session = await getSession();
  if (!session) { window.location.href = redirectTo; return null; }
  return session.user;
}

async function requireAdmin() {
  const user = await requireAuth();
  if (!user) return null;
  const { data } = await sb.from('admins').select('email').eq('email', user.email).single();
  if (!data) { window.location.href = 'dashboard.html'; return null; }
  return user;
}

async function signOut() {
  await sb.auth.signOut();
  window.location.href = 'index.html';
}

// ── Upsert usuario no login ──────────────────────────────────
async function upsertUsuario(user) {
  await sb.from('usuarios').upsert({
    id: user.id,
    email: user.email,
    nome: user.user_metadata?.full_name || '',
    avatar_url: user.user_metadata?.avatar_url || '',
  }, { onConflict: 'id', ignoreDuplicates: false });

  // Garante linha em debitos
  await sb.from('debitos').upsert({
    usuario_id: user.id,
    total_geracoes: 0,
    valor_devido: 0,
    status: 'adimplente',
  }, { onConflict: 'usuario_id', ignoreDuplicates: true });
}

// ── Formatar data ────────────────────────────────────────────
function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
}

// ── Formatar moeda ───────────────────────────────────────────
function fmtBRL(val) {
  return Number(val || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

// ── Spinner helper ───────────────────────────────────────────
function setLoading(btn, loading, text = '') {
  if (!btn) return;
  btn.disabled = loading;
  if (loading) {
    btn._orig = btn.innerHTML;
    btn.innerHTML = `<span class="spinner"></span> ${text || 'Aguarde...'}`;
  } else {
    btn.innerHTML = btn._orig || text;
    btn._orig = null;
  }
}

// ── Modal helpers ────────────────────────────────────────────
function openModal(id)  { document.getElementById(id)?.classList.add('open'); }
function closeModal(id) { document.getElementById(id)?.classList.remove('open'); }

// ── Sidebar mobile toggle ─────────────────────────────────────
function initMobileSidebar() {
  const btn = document.getElementById('sidebar-toggle');
  const sidebar = document.querySelector('.sidebar');
  btn?.addEventListener('click', () => sidebar?.classList.toggle('open'));
}

document.addEventListener('DOMContentLoaded', initMobileSidebar);
