import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://aqwtatpxpdlxbqqpfamx.supabase.co',
    anonKey: 'sb_publishable_PWU0gOBJHa7KE7BYJi8pZA_W84_gTWj',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeNest',
      home: Supabase.instance.client.auth.currentSession == null
          ? const LoginPage()
          : const HomePage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: '邮箱'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _signIn,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  
  // 用来存当前用户的家庭ID
  String? _familyId;
  // 用来存空间节点列表
  List<Map<String, dynamic>> _spaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 加载数据的主逻辑
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      // 1. 查一下当前用户属于哪个家庭
      final memberData = await supabase
          .from('family_members')
          .select('family_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (memberData != null) {
        _familyId = memberData['family_id'];

        // 2. 如果有家庭，就查这个家庭下的所有空间节点
        final spacesData = await supabase
            .from('space_nodes')
            .select()
            .eq('family_id', _familyId!)
            .order('created_at');
        
        _spaces = List<Map<String, dynamic>>.from(spacesData);
      }
    } catch (e) {
      print('加载出错: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 创建家庭的功能
  Future<void> _createFamily() async {
    setState(() => _isLoading = true);
    try {
      // 调用我们之前在数据库里写的 RPC 函数
      await supabase.rpc('create_family', params: {'p_name': '我的家'});
      await _loadData(); // 创建成功后重新加载
    } catch (e) {
      print('创建家庭失败: $e');
      setState(() => _isLoading = false);
    }
  }

  // 添加空间节点（比如加个冰箱）
  Future<void> _addSpaceNode() async {
    if (_familyId == null) return;
    
    // 这里为了简单，先不弹窗，直接默认加一个“新空间”
    // 后面你可以改成弹出一个输入框让用户自己填名字
    final name = '新空间 ${_spaces.length + 1}';
    try {
      await supabase.from('space_nodes').insert({
        'family_id': _familyId,
        'name': name,
        'node_type': 'container',
        'path': name, 
        'created_by': supabase.auth.currentUser!.id,
      });
      _loadData(); // 添加后刷新列表
    } catch (e) {
      print('添加空间失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的空间'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _familyId == null
              ? Center(
                  // 如果没有家庭，显示创建按钮
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('你还没有创建家庭'),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _createFamily,
                        child: const Text('创建我的家'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('空间列表', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            onPressed: _addSpaceNode,
                            icon: const Icon(Icons.add),
                            label: const Text('添加空间'),
                          ),
                        ],
                      ),
                    ),
Expanded(
  child: _spaces.isEmpty
      ? const Center(child: Text('家里空空如也，点右上角添加吧'))
      : ListView(
          children: _buildTreeNodes(null, 0), // 从根节点(parent_id = null)开始渲染
        ),
),
                  ],
                ),
    );
  }
}