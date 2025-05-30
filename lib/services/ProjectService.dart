import 'package:finalmobileproject/models/project.class.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ProjectService {
  final _db = Supabase.instance.client;

  // Get current user's name
  Future<String?> getUserName() async {
    try {
      final user = await _db.auth.currentUser?.userMetadata?['name'];
      if (user == null) return "User";

      return user;
    } catch (e) {
      return null;
    }
  }

  getUserImage() {
    return _db.auth.currentSession?.user.userMetadata?['avatar_url'];
  }

  Future<int> getProjectsCount() async {
    return (await _db
            .from('Projects')
            .select()
            .eq('owner', _db.auth.currentUser?.id as String)
            .count())
        .count;
  }

  // Get completed projects
  Future<List<Map<String, dynamic>>> getCompletedProjects() async {
    try {
      return await _db
          .from('Projects')
          .select()
          .eq('owner', _db.auth.currentUser?.id as String)
          .eq('status', 'completed');
    } catch (e) {
      print('Error getting completed projects: $e');
      return [];
    }
  }

  // Get in progress projects
  Future<List<Map<String, dynamic>>> getInProgressProjects() async {
    try {
      return await _db
          .from('Projects')
          .select()
          .eq('owner', _db.auth.currentUser?.id as String)
          .eq('status', 'inProgress');
    } catch (e) {
      print('Error getting in progress projects: $e');
      return [];
    }
  }

  // Get other status projects (not completed or in progress)
  Future<List<Map<String, dynamic>>> getOtherStatusProjects() async {
    try {
      return await _db
          .from('Projects')
          .select()
          .eq('owner', _db.auth.currentUser?.id as String)
          .not('status', 'in', ['completed', 'inProgress']);
    } catch (e) {
      print('Error getting other status projects: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProjects(
    String? searchphrase,
    ProjectStatus? selectedstatus,
  ) {
    if (searchphrase != null && selectedstatus == null) {
      return Supabase.instance.client
          .from('Projects')
          .select()
          .eq("owner", _db.auth.currentUser?.id as String)
          .ilike('name', '%$searchphrase%');
    } else if (searchphrase != null && selectedstatus != null) {
      return Supabase.instance.client
          .from('Projects')
          .select()
          .eq("owner", _db.auth.currentUser?.id as String)
          .eq('status', selectedstatus.name)
          .ilike('name', '%$searchphrase%');
    } else if (selectedstatus != null) {
      return Supabase.instance.client
          .from('Projects')
          .select()
          .eq("owner", _db.auth.currentUser?.id as String)
          .eq('status', selectedstatus.name);
    }
    return Supabase.instance.client
        .from('Projects')
        .select()
        .eq("owner", _db.auth.currentUser?.id as String);
  }

  Future<String> getProjectsLength(String searchphrase, selectedstatus) async {
    return (await getProjects(
      searchphrase == "" ? null : searchphrase,
      selectedstatus,
    )).length.toString();
  }

  // Add new project
  Future<Map<String, dynamic>> addProject(Project project) async {
    if (project.name.isEmpty) {
      return {'status': 'Error', 'details': 'Project name cannot be empty'};
    }
    if (project.est.isEmpty) {
      return {'status': 'Error', 'details': 'Project estimate cannot be empty'};
    }
    if (project.startDate.isEmpty) {
      return {
        'status': 'Error',
        'details': 'Project start date cannot be empty',
      };
    }
    if (project.endDate.isEmpty) {
      return {'status': 'Error', 'details': 'Project end date cannot be empty'};
    }

    try {
      final id =
          await _db
              .from("Projects")
              .insert({
                'name': project.name,
                'description': project.description,
                'est': project.est,
                'startDate':
                    DateFormat(
                      'd MMM yyyy',
                    ).parse(project.startDate).toIso8601String(),
                'endDate':
                    DateFormat(
                      'd MMM yyyy',
                    ).parse(project.endDate).toIso8601String(),
                'status': project.status.name,
              })
              .select('id')
              .single();

      return {'status': 'Success', 'id': id['id']};
    } on PostgrestException catch (e) {
      return {'status': 'Error', 'details': '${e.message} ${e.code}'};
    }
  }

  // Edit existing project
  Future<Map<String, dynamic>> editProject(
    String projectId,
    Project project,
  ) async {
    try {
      await _db
          .from("Projects")
          .update({
            'name': project.name,
            'description': project.description,
            'est': project.est,
            'startDate':
                DateFormat(
                  'd MMM yyyy',
                ).parse(project.startDate).toIso8601String(),
            'endDate':
                DateFormat(
                  'd MMM yyyy',
                ).parse(project.endDate).toIso8601String(),
            'status': project.status.name,
          })
          .eq('id', projectId);

      return {'status': 'Success'};
    } on PostgrestException catch (e) {
      return {'status': 'Error', 'details': '${e.message} ${e.code}'};
    }
  }

  // Delete project
  Future<Map<String, dynamic>> deleteProject(String projectId) async {
    try {
      await _db.from("Projects").delete().eq('id', projectId).select();
      return {'status': 'Success'};
    } on PostgrestException catch (e) {
      return {'status': 'Error', 'details': '${e.message} ${e.code}'};
    }
  }

  // Update profile picture
  Future<Map<String, dynamic>> updateProfilePicture(String imageUrl) async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) {
        return {'status': 'Error', 'details': 'No user logged in'};
      }

      await _db
          .from('profiles')
          .update({'avatar_url': imageUrl})
          .eq('id', user.id);

      return {'status': 'Success'};
    } on PostgrestException catch (e) {
      return {'status': 'Error', 'details': '${e.message} ${e.code}'};
    }
  }

  Future<Project?> getProject(String projectId) async {
    try {
      final response =
          await _db.from('Projects').select().eq('id', projectId).single();

      return Project(
        id: response['id'].toString(),
        name: response['name'].toString(),
        description: response['description'].toString(),
        est: response['est'].toString(),
        startDate: DateFormat(
          'd MMM yyyy',
        ).format(DateTime.parse(response['startDate'])),
        endDate: DateFormat(
          'd MMM yyyy',
        ).format(DateTime.parse(response['endDate'])),
        status: ProjectStatus.values.firstWhere(
          (e) => e.name == response['status'],
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Future<double> getProjectTasksCount(id) async {
    var total =
        await _db.from('Tasks').select().eq("projectID", int.parse(id)).count();
    var isDone =
        await _db
            .from('Tasks')
            .select()
            .eq("projectID", int.parse(id))
            .eq('isDone', true)
            .count();
    return total.count > 0 ? isDone.count / total.count : -1;
  }
}
