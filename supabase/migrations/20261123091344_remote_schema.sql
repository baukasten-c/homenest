SET local check_function_bodies = off;

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON SEQUENCES FROM "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON SEQUENCES FROM "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON SEQUENCES FROM "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON FUNCTIONS FROM "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON FUNCTIONS FROM "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON FUNCTIONS FROM "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON TABLES FROM "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON TABLES FROM "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL ON TABLES FROM "service_role";

CREATE TABLE "public"."families" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "name"        text                     NOT NULL,
  "invite_code" text                     DEFAULT encode(extensions.gen_random_bytes(6), 'hex'::text),
  "created_at"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "families_invite_code_key" UNIQUE (invite_code),
  CONSTRAINT "families_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."families"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."families" FROM "anon";

CREATE TABLE "public"."family_members" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "family_id"  uuid                     NOT NULL,
  "user_id"    uuid                     NOT NULL,
  "role"       text                     NOT NULL DEFAULT 'member'::text,
  "created_at" timestamp with time zone DEFAULT now(),
  CONSTRAINT "family_members_family_id_user_id_key" UNIQUE (family_id, user_id),
  CONSTRAINT "family_members_pkey" PRIMARY KEY (id),
  CONSTRAINT "family_members_role_check" CHECK ((role = ANY (ARRAY['owner'::text, 'member'::text])))
);

ALTER TABLE "public"."family_members"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."family_members" FROM "anon";

CREATE TABLE "public"."items" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "family_id"     uuid                     NOT NULL,
  "space_node_id" uuid,
  "name"          text                     NOT NULL,
  "category"      text,
  "quantity"      integer                  NOT NULL DEFAULT 1,
  "expiry_date"   date,
  "opened_date"   date,
  "min_quantity"  integer                  DEFAULT 1,
  "note"          text,
  "created_by"    uuid,
  "updated_by"    uuid,
  "created_at"    timestamp with time zone DEFAULT now(),
  "updated_at"    timestamp with time zone DEFAULT now(),
  "marker_x"      numeric,
  "marker_y"      numeric,
  CONSTRAINT "items_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."items"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."items" FROM "anon";

CREATE TABLE "public"."space_nodes" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "family_id"    uuid                     NOT NULL,
  "parent_id"    uuid,
  "name"         text                     NOT NULL,
  "node_type"    text                     DEFAULT 'container'::text,
  "path"         text,
  "visual_type"  text,
  "width"        numeric,
  "height"       numeric,
  "depth"        numeric,
  "position_x"   numeric,
  "position_y"   numeric,
  "position_z"   numeric,
  "photo_url"    text,
  "marker_x"     numeric,
  "marker_y"     numeric,
  "model_params" jsonb                    DEFAULT '{}'::jsonb,
  "created_by"   uuid,
  "created_at"   timestamp with time zone DEFAULT now(),
  "updated_at"   timestamp with time zone DEFAULT now(),
  CONSTRAINT "space_nodes_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."space_nodes"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."space_nodes" FROM "anon";

CREATE OR REPLACE FUNCTION public.consume_item (
  p_item_id uuid,
  p_qty     integer DEFAULT 1
)
  RETURNS void
  LANGUAGE plpgsql
  AS $function$
begin
  update items
  set quantity = greatest(quantity - p_qty, 0),
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_item_id;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."consume_item"(uuid, integer) FROM "anon", "authenticated", "service_role";

CREATE OR REPLACE FUNCTION public.create_family (
  p_name text
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_family_id uuid;
begin
  insert into public.families (name) values (p_name) returning id into v_family_id;

  insert into public.family_members (family_id, user_id, role)
  values (v_family_id, auth.uid(), 'owner');

  return v_family_id;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."create_family"(text) FROM "anon", "authenticated", "service_role";

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
  RETURNS event_trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'pg_catalog'
  AS $function$
DECLARE
  cmd record;
  tbl name;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        SELECT c.relname INTO tbl FROM pg_catalog.pg_class c WHERE c.oid = cmd.objid;
        EXECUTE format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION "public"."rls_auto_enable"() FROM "anon", "authenticated", "service_role";

ALTER TABLE "public"."family_members"
  ADD CONSTRAINT "family_members_family_id_fkey" FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;

ALTER TABLE "public"."family_members"
  ADD CONSTRAINT "family_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."items"
  ADD CONSTRAINT "items_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id);

ALTER TABLE "public"."items"
  ADD CONSTRAINT "items_family_id_fkey" FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;

ALTER TABLE "public"."items"
  ADD CONSTRAINT "items_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES auth.users(id);

ALTER TABLE "public"."space_nodes"
  ADD CONSTRAINT "space_nodes_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id);

ALTER TABLE "public"."space_nodes"
  ADD CONSTRAINT "space_nodes_family_id_fkey" FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;

ALTER TABLE "public"."items"
  ADD CONSTRAINT "items_space_node_id_fkey" FOREIGN KEY (space_node_id) REFERENCES public.space_nodes(id) ON DELETE SET NULL;

ALTER TABLE "public"."space_nodes"
  ADD CONSTRAINT "space_nodes_parent_id_fkey" FOREIGN KEY (parent_id) REFERENCES public.space_nodes(id) ON DELETE CASCADE;

CREATE VIEW "public"."v_item_search" WITH (security_invoker=true) AS  SELECT i.id AS item_id,
    i.family_id,
    i.name AS item_name,
    i.quantity,
    i.expiry_date,
    i.opened_date,
    sn.name AS space_name,
    sn.path AS space_path,
    sn.photo_url,
    i.marker_x,
    i.marker_y,
        CASE
            WHEN (i.expiry_date IS NULL) THEN NULL::integer
            ELSE (i.expiry_date - CURRENT_DATE)
        END AS days_left,
    i.space_node_id
   FROM (public.items i
     LEFT JOIN public.space_nodes sn ON ((sn.id = i.space_node_id)));

CREATE POLICY "members can view their families" ON "public"."families"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.family_members
  WHERE ((family_members.family_id = families.id) AND (family_members.user_id = auth.uid())))));

CREATE POLICY "members can view own membership" ON "public"."family_members"
  FOR SELECT
  TO "authenticated"
  USING ((user_id = auth.uid()));

CREATE POLICY "family members can access items" ON "public"."items"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.family_members
  WHERE ((family_members.family_id = items.family_id) AND (family_members.user_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.family_members
  WHERE ((family_members.family_id = items.family_id) AND (family_members.user_id = auth.uid())))));

CREATE POLICY "family members can access space nodes" ON "public"."space_nodes"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.family_members
  WHERE ((family_members.family_id = space_nodes.family_id) AND (family_members.user_id = auth.uid())))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.family_members
  WHERE ((family_members.family_id = space_nodes.family_id) AND (family_members.user_id = auth.uid())))));

CREATE EVENT TRIGGER "ensure_rls"
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION "public"."rls_auto_enable"();

GRANT EXECUTE ON FUNCTION "public"."consume_item"(uuid, integer) TO PUBLIC;

REVOKE ALL ON FUNCTION "public"."consume_item"(uuid, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."consume_item"(uuid, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."create_family"(text) TO PUBLIC;

REVOKE ALL ON FUNCTION "public"."create_family"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."create_family"(text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."rls_auto_enable"() TO PUBLIC;

REVOKE ALL ON FUNCTION "public"."rls_auto_enable"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."rls_auto_enable"() TO "postgres";

REVOKE ALL ON TABLE "public"."families" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."families" TO "authenticated";

REVOKE ALL ON TABLE "public"."families" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."families" TO "postgres";

REVOKE ALL ON TABLE "public"."families" FROM "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."families" TO "service_role";

REVOKE ALL ON TABLE "public"."family_members" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."family_members" TO "authenticated";

REVOKE ALL ON TABLE "public"."family_members" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."family_members" TO "postgres";

REVOKE ALL ON TABLE "public"."family_members" FROM "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."family_members" TO "service_role";

REVOKE ALL ON TABLE "public"."items" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."items" TO "authenticated";

REVOKE ALL ON TABLE "public"."items" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."items" TO "postgres";

REVOKE ALL ON TABLE "public"."items" FROM "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."items" TO "service_role";

REVOKE ALL ON TABLE "public"."space_nodes" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."space_nodes" TO "authenticated";

REVOKE ALL ON TABLE "public"."space_nodes" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."space_nodes" TO "postgres";

REVOKE ALL ON TABLE "public"."space_nodes" FROM "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."space_nodes" TO "service_role";

REVOKE ALL ON TABLE "public"."v_item_search" FROM "anon";

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."v_item_search" TO "anon";

REVOKE ALL ON TABLE "public"."v_item_search" FROM "authenticated";

GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE "public"."v_item_search" TO "authenticated";

REVOKE ALL ON TABLE "public"."v_item_search" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."v_item_search" TO "postgres";

REVOKE ALL ON TABLE "public"."v_item_search" FROM "service_role";

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLE "public"."v_item_search" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLES TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLES TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON TABLES TO "service_role";

