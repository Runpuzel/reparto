import 'package:supabase_flutter/supabase_flutter.dart';

/// Convenience accessor for the global Supabase client.
SupabaseClient get supabase => Supabase.instance.client;

/// Shorthand for the current authenticated user (nullable).
User? get currentAuthUser => supabase.auth.currentUser;
