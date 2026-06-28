import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'firebase_options.dart';
import 'validators.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseError;
  var firebaseReady = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } on Object catch (error) {
    firebaseError = error;
  }

  runApp(MyTaskManagerApp(firebaseReady: firebaseReady, error: firebaseError));
}

enum TaskStatus {
  notStarted('notStarted', "Haven't Started", Color(0xFFE63946)),
  inProgress('inProgress', 'In Progress', Color(0xFFFFC43D)),
  done('done', 'Done', Color(0xFF2A9D8F));

  const TaskStatus(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static TaskStatus fromValue(Object? value) {
    return TaskStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TaskStatus.notStarted,
    );
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.reference,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.dueDate,
  });

  final String id;
  final DocumentReference<Map<String, dynamic>> reference;
  final String title;
  final String description;
  final TaskStatus status;
  final DateTime? createdAt;
  final DateTime? dueDate;

  factory TaskItem.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final dueDate = data['dueDate'];

    return TaskItem(
      id: doc.id,
      reference: doc.reference,
      title: data['title']?.toString() ?? 'Untitled task',
      description: data['description']?.toString() ?? '',
      status: TaskStatus.fromValue(data['status']),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      dueDate: dueDate is Timestamp ? dueDate.toDate() : null,
    );
  }
}

class MyTaskManagerApp extends StatelessWidget {
  const MyTaskManagerApp({super.key, required this.firebaseReady, this.error});

  final bool firebaseReady;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF28666E);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Task Manager',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F3),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: firebaseReady
          ? const AuthGate()
          : FirebaseSetupScreen(error: error),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return DashboardScreen(user: user);
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.cloud_sync_outlined,
                    size: 58,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Firebase setup needed',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add your Firebase configuration to connect authentication and task storage.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Startup error: $error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showSnackBar(context, _authMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in and pick up exactly where you left your tasks.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) => validateEmail(value ?? ''),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => validatePassword(value ?? ''),
              onFieldSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _login,
              icon: _isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('Login'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
              child: const Text('Create a new account'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showSnackBar(context, _authMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Create account',
      subtitle: 'Register with email and password to keep your tasks private.',
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) => validateEmail(value ?? ''),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => validatePassword(value ?? ''),
              onFieldSubmitted: (_) => _register(),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _register,
              icon: _isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBackButton = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F3),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        MediaQuery.of(context).padding.top + 26,
                        24,
                        34,
                      ),
                      color: const Color(0xFF2A9D8F),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showBackButton)
                                IconButton.filled(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back),
                                  tooltip: 'Back',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF2A9D8F),
                                  ),
                                ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.task_alt,
                                      size: 34,
                                      color: Color(0xFF2A9D8F),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'My Task Manager',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        Text(
                                          'Plan your day with clarity',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 22,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF1F2937),
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    subtitle,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(color: Colors.black54),
                                  ),
                                  const SizedBox(height: 24),
                                  child,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.user});

  final User user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  DateTime? _dateFilter;
  TaskStatus? _statusFilter;

  CollectionReference<Map<String, dynamic>> get _tasks => FirebaseFirestore
      .instance
      .collection('users')
      .doc(widget.user.uid)
      .collection('tasks');

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _dateOnly(_focusedDay);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await _tasks.doc(taskId).delete();
      if (mounted) {
        _showSnackBar(context, 'Task deleted');
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        _showSnackBar(context, error.message ?? 'Could not delete task');
      }
    }
  }

  Future<void> _changeStatus(TaskItem task, TaskStatus status) async {
    try {
      await task.reference.update({'status': status.value});
    } on FirebaseException catch (error) {
      if (mounted) {
        _showSnackBar(context, error.message ?? 'Could not update status');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _tasks.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load tasks: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks =
              (snapshot.data?.docs ?? []).map(TaskItem.fromDocument).toList()
                ..sort(_sortByDueDate);
          final filteredTasks = _filteredTasks(tasks);
          final tasksByDate = _tasksByDate(tasks);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DashboardSummary(tasks: tasks),
                      const SizedBox(height: 12),
                      StatusLegend(
                        tasks: tasks,
                        selectedStatus: _statusFilter,
                        onStatusSelected: (status) {
                          setState(() {
                            _statusFilter = status;
                            _dateFilter = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      CalendarPanel(
                        focusedDay: _focusedDay,
                        selectedDay: _selectedDay,
                        tasksByDate: tasksByDate,
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = _dateOnly(selectedDay);
                            _focusedDay = focusedDay;
                            _dateFilter = _dateOnly(selectedDay);
                            _statusFilter = null;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _filterTitle,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (_hasActiveFilter)
                            TextButton.icon(
                              onPressed: _openAllTasksScreen,
                              icon: const Icon(Icons.list_alt_outlined),
                              label: const Text('Show all'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              if (tasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyTaskState(onAddTask: _openAddTask),
                )
              else if (filteredTasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyFilterState(
                    title: _emptyFilterTitle,
                    onShowAll: _openAllTasksScreen,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: filteredTasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];

                      return TaskTile(
                        task: task,
                        onEdit: () => _openEditTask(task),
                        onDelete: () async {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Delete task?'),
                              content: const Text(
                                'This task will be removed permanently.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton.icon(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (shouldDelete == true) {
                            await _deleteTask(task.id);
                          }
                        },
                        onStatusChanged: (status) =>
                            _changeStatus(task, status),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTask,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  void _openAddTask() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AddTaskScreen(tasks: _tasks)),
    );
  }

  void _openEditTask(TaskItem task) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => EditTaskScreen(task: task)));
  }

  void _openAllTasksScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MyTasksScreen(tasks: _tasks)),
    );
  }

  bool get _hasActiveFilter => _dateFilter != null || _statusFilter != null;

  String get _filterTitle {
    final status = _statusFilter;
    if (status != null) {
      return '${status.label} Tasks';
    }

    final date = _dateFilter;
    if (date != null) {
      return 'Tasks on ${_formatShortDate(date)}';
    }

    return 'All Tasks';
  }

  String get _emptyFilterTitle {
    final status = _statusFilter;
    if (status != null) {
      return 'No ${status.label.toLowerCase()} tasks';
    }

    final date = _dateFilter;
    if (date != null) {
      return 'No tasks due on ${_formatShortDate(date)}';
    }

    return 'No tasks found';
  }

  List<TaskItem> _filteredTasks(List<TaskItem> tasks) {
    final status = _statusFilter;
    if (status != null) {
      return tasks.where((task) => task.status == status).toList();
    }

    final date = _dateFilter;
    if (date != null) {
      return tasks.where((task) => _isSameDay(task.dueDate, date)).toList();
    }

    return tasks;
  }
}

class DashboardSummary extends StatelessWidget {
  const DashboardSummary({super.key, required this.tasks});

  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final done = tasks.where((task) => task.status == TaskStatus.done).length;
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A9D8F),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dashboard_customize_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$done/$total tasks done',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      total == 0
                          ? 'Create your first task'
                          : '${(progress * 100).round()}% completed',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key, required this.tasks});

  final CollectionReference<Map<String, dynamic>> tasks;

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  Future<void> _deleteTask(String taskId) async {
    try {
      await widget.tasks.doc(taskId).delete();
      if (mounted) {
        _showSnackBar(context, 'Task deleted');
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        _showSnackBar(context, error.message ?? 'Could not delete task');
      }
    }
  }

  Future<void> _changeStatus(TaskItem task, TaskStatus status) async {
    try {
      await task.reference.update({'status': status.value});
    } on FirebaseException catch (error) {
      if (mounted) {
        _showSnackBar(context, error.message ?? 'Could not update status');
      }
    }
  }

  void _openEditTask(TaskItem task) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => EditTaskScreen(task: task)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.tasks.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load tasks: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks =
              (snapshot.data?.docs ?? []).map(TaskItem.fromDocument).toList()
                ..sort(_sortByDueDate);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 150,
                backgroundColor: const Color(0xFF2A9D8F),
                foregroundColor: Colors.white,
                title: const Text('My Tasks'),
                flexibleSpace: FlexibleSpaceBar(
                  background: ColoredBox(
                    color: const Color(0xFF2A9D8F),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 58, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'All Tasks',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${tasks.length} total tasks',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (tasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyTaskState(
                    onAddTask: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AddTaskScreen(tasks: widget.tasks),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = tasks[index];

                      return TaskTile(
                        task: task,
                        onEdit: () => _openEditTask(task),
                        onDelete: () async {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Delete task?'),
                              content: const Text(
                                'This task will be removed permanently.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton.icon(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (shouldDelete == true) {
                            await _deleteTask(task.id);
                          }
                        },
                        onStatusChanged: (status) =>
                            _changeStatus(task, status),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class StatusLegend extends StatelessWidget {
  const StatusLegend({
    super.key,
    required this.tasks,
    required this.selectedStatus,
    required this.onStatusSelected,
  });

  final List<TaskItem> tasks;
  final TaskStatus? selectedStatus;
  final ValueChanged<TaskStatus> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TaskStatus.values.map((status) {
        final count = tasks.where((task) => task.status == status).length;
        final isSelected = selectedStatus == status;

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onStatusSelected(status),
          child: StatusPill(
            status: status,
            label: '${status.label}: $count',
            isSelected: isSelected,
          ),
        );
      }).toList(),
    );
  }
}

class CalendarPanel extends StatelessWidget {
  const CalendarPanel({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.tasksByDate,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final Map<DateTime, List<TaskItem>> tasksByDate;
  final OnDaySelected onDaySelected;
  final void Function(DateTime focusedDay) onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TableCalendar<TaskItem>(
        firstDay: DateTime.utc(2020),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(day, selectedDay),
        eventLoader: (day) => tasksByDate[_dateOnly(day)] ?? const [],
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        calendarBuilders: CalendarBuilders<TaskItem>(
          markerBuilder: (context, day, tasks) {
            if (tasks.isEmpty) {
              return null;
            }

            final color = _calendarColorFor(tasks);
            return Positioned(
              bottom: 5,
              child: Container(
                width: 22,
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class EmptyTaskState extends StatelessWidget {
  const EmptyTaskState({super.key, required this.onAddTask});

  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFFA8DADC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.playlist_add_check_circle, size: 52),
            ),
            const SizedBox(height: 22),
            Text(
              'No tasks yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first task with a status and completion date.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyFilterState extends StatelessWidget {
  const EmptyFilterState({
    super.key,
    required this.title,
    required this.onShowAll,
  });

  final String title;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECEF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.filter_alt_off_outlined, size: 42),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onShowAll,
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Show all tasks'),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final TaskItem task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<TaskStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: task.status.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      task.status == TaskStatus.done
                          ? Icons.check
                          : Icons.flag_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(task.description),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusPill(status: task.status),
                            InfoPill(
                              icon: Icons.event_available_outlined,
                              label: task.dueDate == null
                                  ? 'No date'
                                  : 'Due ${_formatShortDate(task.dueDate!)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<TaskStatus>(
                    tooltip: 'Change status',
                    initialValue: task.status,
                    onSelected: onStatusChanged,
                    itemBuilder: (context) => TaskStatus.values
                        .map(
                          (status) => PopupMenuItem(
                            value: status,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: status.color,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Text(status.label),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddTaskScreen extends StatelessWidget {
  const AddTaskScreen({super.key, required this.tasks});

  final CollectionReference<Map<String, dynamic>> tasks;

  Future<void> _saveTask(
    String title,
    String description,
    TaskStatus status,
    DateTime dueDate,
  ) {
    return tasks.add({
      'title': title,
      'description': description,
      'status': status.value,
      'dueDate': Timestamp.fromDate(_dateOnly(dueDate)),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return TaskFormScreen(
      title: 'Add Task',
      buttonLabel: 'Save Task',
      buttonIcon: Icons.save_outlined,
      initialDueDate: DateTime.now(),
      onSave: _saveTask,
    );
  }
}

class EditTaskScreen extends StatelessWidget {
  const EditTaskScreen({super.key, required this.task});

  final TaskItem task;

  Future<void> _updateTask(
    String title,
    String description,
    TaskStatus status,
    DateTime dueDate,
  ) {
    return task.reference.update({
      'title': title,
      'description': description,
      'status': status.value,
      'dueDate': Timestamp.fromDate(_dateOnly(dueDate)),
    });
  }

  @override
  Widget build(BuildContext context) {
    return TaskFormScreen(
      title: 'Edit Task',
      buttonLabel: 'Update Task',
      buttonIcon: Icons.done,
      initialTitle: task.title,
      initialDescription: task.description,
      initialStatus: task.status,
      initialDueDate: task.dueDate ?? DateTime.now(),
      onSave: _updateTask,
    );
  }
}

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.title,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onSave,
    required this.initialDueDate,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialStatus = TaskStatus.notStarted,
  });

  final String title;
  final String buttonLabel;
  final IconData buttonIcon;
  final String initialTitle;
  final String initialDescription;
  final TaskStatus initialStatus;
  final DateTime initialDueDate;
  final Future<void> Function(
    String title,
    String description,
    TaskStatus status,
    DateTime dueDate,
  )
  onSave;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TaskStatus _status;
  late DateTime _dueDate;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _status = widget.initialStatus;
    _dueDate = _dateOnly(widget.initialDueDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );

    if (pickedDate != null) {
      setState(() => _dueDate = _dateOnly(pickedDate));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.onSave(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _status,
        _dueDate,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        _showSnackBar(context, error.message ?? 'Could not save task');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Task title',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) => validateTaskTitle(value ?? ''),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TaskStatus.values.map((status) {
                    return ChoiceChip(
                      selected: _status == status,
                      avatar: Icon(Icons.circle, color: status.color, size: 14),
                      label: Text(status.label),
                      onSelected: (_) => setState(() => _status = status),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('Date to be completed'),
                    subtitle: Text(_formatShortDate(_dueDate)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: _pickDueDate,
                  ),
                ),
                const SizedBox(height: 26),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(widget.buttonIcon),
                  label: Text(widget.buttonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.status,
    this.label,
    this.isSelected = false,
  });

  final TaskStatus status;
  final String? label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final textColor = status == TaskStatus.inProgress
        ? const Color(0xFF4D3700)
        : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: Text(
        label ?? status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

String _authMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-email' => 'Please enter a valid email address.',
    'weak-password' => 'Password must be at least 6 characters.',
    'email-already-in-use' => 'That email is already registered.',
    'account-exists-with-different-credential' =>
      'This email already uses another login method.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Invalid email or password.',
    _ => error.message ?? 'Authentication failed.',
  };
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

int _sortByDueDate(TaskItem first, TaskItem second) {
  final firstDueDate = first.dueDate ?? DateTime(9999);
  final secondDueDate = second.dueDate ?? DateTime(9999);
  final dueCompare = firstDueDate.compareTo(secondDueDate);
  if (dueCompare != 0) {
    return dueCompare;
  }

  final firstCreatedAt = first.createdAt ?? DateTime(9999);
  final secondCreatedAt = second.createdAt ?? DateTime(9999);
  return firstCreatedAt.compareTo(secondCreatedAt);
}

Map<DateTime, List<TaskItem>> _tasksByDate(List<TaskItem> tasks) {
  final byDate = <DateTime, List<TaskItem>>{};

  for (final task in tasks) {
    final dueDate = task.dueDate;
    if (dueDate == null) {
      continue;
    }

    final key = _dateOnly(dueDate);
    byDate.putIfAbsent(key, () => []).add(task);
  }

  return byDate;
}

Color _calendarColorFor(List<TaskItem> tasks) {
  if (tasks.any((task) => task.status == TaskStatus.notStarted)) {
    return TaskStatus.notStarted.color;
  }

  if (tasks.any((task) => task.status == TaskStatus.inProgress)) {
    return TaskStatus.inProgress.color;
  }

  return TaskStatus.done.color;
}

bool _isSameDay(DateTime? first, DateTime second) {
  if (first == null) {
    return false;
  }

  return isSameDay(first, second);
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _formatShortDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();

  return '$day/$month/$year';
}
