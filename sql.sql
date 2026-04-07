-- ============================================================
-- AUDITCV — Setup completo do banco de dados
-- Execute no SQL Editor do Supabase (Project > SQL Editor)
-- ============================================================

-- ── 1. Tabela de usuários ────────────────────────────────────
CREATE TABLE IF NOT EXISTS usuarios (
  id          UUID PRIMARY KEY DEFAULT auth.uid(),
  email       TEXT UNIQUE NOT NULL,
  nome        TEXT,
  telefone    TEXT,
  avatar_url  TEXT,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ── 2. Tabela de gerações ────────────────────────────────────
CREATE TABLE IF NOT EXISTS geracoes (
  id                 SERIAL PRIMARY KEY,
  usuario_id         UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  modelo             TEXT CHECK (modelo IN ('simple', 'ats', 'ia_magica')),
  cargo_alvo         TEXT,
  conteudo_original  TEXT,
  conteudo_gerado    TEXT,
  data_geracao       TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status_pagamento   TEXT DEFAULT 'pendente'
);

-- ── 3. Tabela de débitos ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS debitos (
  usuario_id      UUID PRIMARY KEY REFERENCES usuarios(id) ON DELETE CASCADE,
  total_geracoes  INT DEFAULT 0,
  valor_devido    DECIMAL(10,2) DEFAULT 0,
  status          TEXT DEFAULT 'adimplente'
                  CHECK (status IN ('adimplente', 'pendente', 'bloqueado')),
  ultima_geracao  TIMESTAMP WITH TIME ZONE,
  updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ── 4. Tabela de admins ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS admins (
  email TEXT PRIMARY KEY
);

-- ── 5. Inserir o admin (troque pelo seu email real) ──────────
INSERT INTO admins (email) VALUES ('admin@auditcv.com')
ON CONFLICT (email) DO NOTHING;

-- ── 6. RLS — Habilitar segurança por linha ───────────────────
ALTER TABLE usuarios  ENABLE ROW LEVEL SECURITY;
ALTER TABLE geracoes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE debitos   ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins    ENABLE ROW LEVEL SECURITY;

-- ── 7. Políticas RLS — usuarios ──────────────────────────────
CREATE POLICY "user_self_access" ON usuarios
  FOR ALL USING (auth.uid() = id);

CREATE POLICY "admin_all_usuarios" ON usuarios
  FOR ALL USING (auth.email() IN (SELECT email FROM admins));

-- ── 8. Políticas RLS — geracoes ──────────────────────────────
CREATE POLICY "user_own_geracoes" ON geracoes
  FOR ALL USING (auth.uid() = usuario_id);

CREATE POLICY "admin_all_geracoes" ON geracoes
  FOR ALL USING (auth.email() IN (SELECT email FROM admins));

-- ── 9. Políticas RLS — debitos ───────────────────────────────
CREATE POLICY "user_own_debito" ON debitos
  FOR ALL USING (auth.uid() = usuario_id);

CREATE POLICY "admin_all_debitos" ON debitos
  FOR ALL USING (auth.email() IN (SELECT email FROM admins));

-- ── 10. Políticas RLS — admins ───────────────────────────────
CREATE POLICY "admin_read_admins" ON admins
  FOR SELECT USING (auth.email() IN (SELECT email FROM admins));

-- ── 11. Trigger: criar perfil e débito automaticamente ───────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Inserir em usuarios
  INSERT INTO public.usuarios (id, email, nome, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO UPDATE SET
    email      = EXCLUDED.email,
    nome       = COALESCE(EXCLUDED.nome, usuarios.nome),
    avatar_url = COALESCE(EXCLUDED.avatar_url, usuarios.avatar_url);

  -- Inserir em debitos
  INSERT INTO public.debitos (usuario_id)
  VALUES (NEW.id)
  ON CONFLICT (usuario_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger no auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 12. Índices de performance ───────────────────────────────
CREATE INDEX IF NOT EXISTS idx_geracoes_usuario    ON geracoes(usuario_id);
CREATE INDEX IF NOT EXISTS idx_geracoes_data       ON geracoes(data_geracao DESC);
CREATE INDEX IF NOT EXISTS idx_debitos_usuario     ON debitos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_debitos_status      ON debitos(status);

-- ── FIM ──────────────────────────────────────────────────────
-- Verifique as tabelas em: Table Editor > usuarios, geracoes, debitos, admins
