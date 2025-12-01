-- Create triggers to automatically log family activities
-- These triggers are SECURITY DEFINER so they can insert logs even with RLS
-- Safe to run multiple times (drops existing triggers/functions first)

-- Helper function to get family_member linked_user_id from ID
CREATE OR REPLACE FUNCTION public.get_member_linked_user_id(member_id UUID)
RETURNS UUID AS $$
DECLARE
    user_id UUID;
BEGIN
    SELECT linked_user_id INTO user_id FROM public.family_members WHERE id = member_id;
    RETURN user_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ==========================================
-- FAMILY MEMBERS ACTIVITY LOGGING
-- ==========================================

CREATE OR REPLACE FUNCTION public.log_family_member_activity()
RETURNS TRIGGER AS $$
DECLARE
    user_id UUID;
BEGIN
    -- Get the user ID from the session (current user making the change)
    user_id := auth.uid();

    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.family_activity_log (
            family_id,
            action_by_user_id,
            action_by_member_id,
            action_type,
            action_subject_id,
            action_subject_type,
            subject_name,
            action_details
        ) VALUES (
            NEW.family_id,
            user_id,
            NEW.id,
            'member_added'::public.activity_type,
            NEW.id::TEXT,
            'family_member'::public.subject_type,
            NEW.name,
            jsonb_build_object(
                'colorHex', NEW.color_hex,
                'isDriver', NEW.is_driver
            )
        );

    ELSIF TG_OP = 'UPDATE' THEN
        -- Only log if meaningful changes occurred
        IF OLD.name IS DISTINCT FROM NEW.name OR
           OLD.color_hex IS DISTINCT FROM NEW.color_hex OR
           OLD.is_driver IS DISTINCT FROM NEW.is_driver OR
           OLD.linked_user_id IS DISTINCT FROM NEW.linked_user_id THEN

            INSERT INTO public.family_activity_log (
                family_id,
                action_by_user_id,
                action_by_member_id,
                action_type,
                action_subject_id,
                action_subject_type,
                subject_name,
                action_details
            ) VALUES (
                NEW.family_id,
                user_id,
                NEW.id,
                'member_edited'::public.activity_type,
                NEW.id::TEXT,
                'family_member'::public.subject_type,
                NEW.name,
                jsonb_build_object(
                    'changedFields', jsonb_strip_nulls(jsonb_build_object(
                        'name', CASE WHEN OLD.name IS DISTINCT FROM NEW.name THEN jsonb_build_object('old', OLD.name, 'new', NEW.name) ELSE NULL END,
                        'colorHex', CASE WHEN OLD.color_hex IS DISTINCT FROM NEW.color_hex THEN jsonb_build_object('old', OLD.color_hex, 'new', NEW.color_hex) ELSE NULL END,
                        'isDriver', CASE WHEN OLD.is_driver IS DISTINCT FROM NEW.is_driver THEN jsonb_build_object('old', OLD.is_driver, 'new', NEW.is_driver) ELSE NULL END,
                        'linkedUser', CASE WHEN OLD.linked_user_id IS DISTINCT FROM NEW.linked_user_id THEN jsonb_build_object('old', OLD.linked_user_id::TEXT, 'new', NEW.linked_user_id::TEXT) ELSE NULL END
                    ))
                )
            );
        END IF;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.family_activity_log (
            family_id,
            action_by_user_id,
            action_by_member_id,
            action_type,
            action_subject_id,
            action_subject_type,
            subject_name,
            action_details
        ) VALUES (
            OLD.family_id,
            user_id,
            NULL,
            'member_deleted'::public.activity_type,
            OLD.id::TEXT,
            'family_member'::public.subject_type,
            OLD.name,
            jsonb_build_object('deletedAt', CURRENT_TIMESTAMP)
        );
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS family_members_activity_trigger ON public.family_members;
CREATE TRIGGER family_members_activity_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.family_members
    FOR EACH ROW
    EXECUTE FUNCTION public.log_family_member_activity();

-- ==========================================
-- DRIVERS ACTIVITY LOGGING
-- ==========================================

CREATE OR REPLACE FUNCTION public.log_driver_activity()
RETURNS TRIGGER AS $$
DECLARE
    user_id UUID;
    family_id UUID;
BEGIN
    user_id := auth.uid();
    family_id := COALESCE(NEW.family_id, OLD.family_id);

    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.family_activity_log (
            family_id,
            action_by_user_id,
            action_type,
            action_subject_id,
            action_subject_type,
            subject_name,
            action_details
        ) VALUES (
            family_id,
            user_id,
            'driver_created'::public.activity_type,
            NEW.id::TEXT,
            'driver'::public.subject_type,
            NEW.name,
            jsonb_build_object(
                'phone', NEW.phone,
                'email', NEW.email,
                'travelTimeMinutes', NEW.travel_time_minutes
            )
        );

    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.name IS DISTINCT FROM NEW.name OR
           OLD.phone IS DISTINCT FROM NEW.phone OR
           OLD.email IS DISTINCT FROM NEW.email OR
           OLD.travel_time_minutes IS DISTINCT FROM NEW.travel_time_minutes THEN

            INSERT INTO public.family_activity_log (
                family_id,
                action_by_user_id,
                action_type,
                action_subject_id,
                action_subject_type,
                subject_name,
                action_details
            ) VALUES (
                family_id,
                user_id,
                'driver_updated'::public.activity_type,
                NEW.id::TEXT,
                'driver'::public.subject_type,
                NEW.name,
                jsonb_build_object(
                    'changedFields', jsonb_strip_nulls(jsonb_build_object(
                        'name', CASE WHEN OLD.name IS DISTINCT FROM NEW.name THEN jsonb_build_object('old', OLD.name, 'new', NEW.name) ELSE NULL END,
                        'phone', CASE WHEN OLD.phone IS DISTINCT FROM NEW.phone THEN jsonb_build_object('old', OLD.phone, 'new', NEW.phone) ELSE NULL END,
                        'email', CASE WHEN OLD.email IS DISTINCT FROM NEW.email THEN jsonb_build_object('old', OLD.email, 'new', NEW.email) ELSE NULL END,
                        'travelTime', CASE WHEN OLD.travel_time_minutes IS DISTINCT FROM NEW.travel_time_minutes THEN jsonb_build_object('old', OLD.travel_time_minutes, 'new', NEW.travel_time_minutes) ELSE NULL END
                    ))
                )
            );
        END IF;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.family_activity_log (
            family_id,
            action_by_user_id,
            action_type,
            action_subject_id,
            action_subject_type,
            subject_name,
            action_details
        ) VALUES (
            family_id,
            user_id,
            'driver_deleted'::public.activity_type,
            OLD.id::TEXT,
            'driver'::public.subject_type,
            OLD.name,
            jsonb_build_object('deletedAt', CURRENT_TIMESTAMP)
        );
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS drivers_activity_trigger ON public.drivers;
CREATE TRIGGER drivers_activity_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.drivers
    FOR EACH ROW
    EXECUTE FUNCTION public.log_driver_activity();

-- ==========================================
-- SAVED ADDRESSES ACTIVITY LOGGING
-- ==========================================

CREATE OR REPLACE FUNCTION public.log_saved_address_activity()
RETURNS TRIGGER AS $$
DECLARE
    user_id UUID;
BEGIN
    user_id := auth.uid();

    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.family_activity_log (
            family_id,
            action_by_user_id,
            action_type,
            action_subject_id,
            action_subject_type,
            subject_name,
            action_details
        ) VALUES (
            NEW.family_id,
            user_id,
            'address_added'::public.activity_type,
            NEW.id::TEXT,
            'address'::public.subject_type,
            NEW.name,
            jsonb_build_object(
                'address', NEW.address,
                'latitude', NEW.latitude,
                'longitude', NEW.longitude
            )
        );

    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.name IS DISTINCT FROM NEW.name OR
           OLD.address IS DISTINCT FROM NEW.address OR
           OLD.latitude IS DISTINCT FROM NEW.latitude OR
           OLD.longitude IS DISTINCT FROM NEW.longitude THEN

            INSERT INTO public.family_activity_log (
                family_id,
                action_by_user_id,
                action_type,
                action_subject_id,
                action_subject_type,
                subject_name,
                action_details
            ) VALUES (
                NEW.family_id,
                user_id,
                'address_updated'::public.activity_type,
                NEW.id::TEXT,
                'address'::public.subject_type,
                NEW.name,
                jsonb_build_object(
                    'changedFields', jsonb_strip_nulls(jsonb_build_object(
                        'name', CASE WHEN OLD.name IS DISTINCT FROM NEW.name THEN jsonb_build_object('old', OLD.name, 'new', NEW.name) ELSE NULL END,
                        'address', CASE WHEN OLD.address IS DISTINCT FROM NEW.address THEN jsonb_build_object('old', OLD.address, 'new', NEW.address) ELSE NULL END,
                        'coordinates', CASE WHEN OLD.latitude IS DISTINCT FROM NEW.latitude OR OLD.longitude IS DISTINCT FROM NEW.longitude THEN 'updated' ELSE NULL END
                    ))
                )
            );
        END IF;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.family_activity_log (
            family_id,
            action_by_user_id,
            action_type,
            action_subject_id,
            action_subject_type,
            subject_name,
            action_details
        ) VALUES (
            OLD.family_id,
            user_id,
            'address_deleted'::public.activity_type,
            OLD.id::TEXT,
            'address'::public.subject_type,
            OLD.name,
            jsonb_build_object('deletedAt', CURRENT_TIMESTAMP)
        );
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS saved_addresses_activity_trigger ON public.saved_addresses;
CREATE TRIGGER saved_addresses_activity_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.saved_addresses
    FOR EACH ROW
    EXECUTE FUNCTION public.log_saved_address_activity();

-- ==========================================
-- SHARED CALENDARS ACTIVITY LOGGING
-- ==========================================

CREATE OR REPLACE FUNCTION public.log_shared_calendar_activity()
RETURNS TRIGGER AS $$
DECLARE
    user_id UUID;
BEGIN
    user_id := auth.uid();

    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.family_activity_log (
            family_id,
            action_by_user_id,
            action_type,
            action_subject_id,
            action_subject_type,
            subject_name,
            action_details
        ) VALUES (
            NEW.family_id,
            user_id,
            'calendar_shared'::public.activity_type,
            NEW.id::TEXT,
            'shared_calendar'::public.subject_type,
            NEW.calendar_name,
            jsonb_build_object(
                'calendarId', NEW.calendar_id,
                'colorHex', NEW.calendar_color_hex
            )
        );

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.family_activity_log (
            family_id,
            action_by_user_id,
            action_type,
            action_subject_id,
            action_subject_type,
            subject_name,
            action_details
        ) VALUES (
            OLD.family_id,
            user_id,
            'calendar_removed'::public.activity_type,
            OLD.id::TEXT,
            'shared_calendar'::public.subject_type,
            OLD.calendar_name,
            jsonb_build_object('removedAt', CURRENT_TIMESTAMP)
        );
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS shared_calendars_activity_trigger ON public.shared_calendars;
CREATE TRIGGER shared_calendars_activity_trigger
    AFTER INSERT OR DELETE ON public.shared_calendars
    FOR EACH ROW
    EXECUTE FUNCTION public.log_shared_calendar_activity();
