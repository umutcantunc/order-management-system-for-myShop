import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../constants/app_colors.dart';
import 'edit_advance_screen.dart';

class AdminAdvancesScreen extends StatefulWidget {
  const AdminAdvancesScreen({Key? key}) : super(key: key);

  @override
  State<AdminAdvancesScreen> createState() => _AdminAdvancesScreenState();
}

class _AdminAdvancesScreenState extends State<AdminAdvancesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    await Future.wait([
      transactionProvider.loadAdvanceTransactions(),
      userProvider.loadUsers(),
    ]);
  }

  String _getUserName(String userId, List<UserModel> users) {
    try {
      return users.firstWhere((u) => u.uid == userId).name;
    } catch (e) {
      return 'Bilinmeyen';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      body: Consumer2<TransactionProvider, UserProvider>(
        builder: (context, transactionProvider, userProvider, child) {
          if (transactionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final advances = transactionProvider.transactions;
          final users = userProvider.users;

          if (advances.isEmpty) {
            return Center(
              child: Text(
                'Henüz avans talebi bulunmamaktadır',
                style: TextStyle(color: AppColors.textGray),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: advances.length,
            itemBuilder: (context, index) {
              return _buildAdvanceCard(context, advances[index], users);
            },
          );
        },
      ),
    );
  }

  Widget _buildAdvanceCard(BuildContext context, TransactionModel advance, List<UserModel> users) {
    final userName = _getUserName(advance.userId, users);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.mediumGray,
      child: ListTile(
        title: Text(
          userName,
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd.MM.yyyy').format(advance.date),
              style: TextStyle(color: AppColors.textGray),
            ),
            if (advance.description.isNotEmpty)
              Text(
                advance.description,
                style: TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${advance.amount.toStringAsFixed(2)} ₺',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.primaryOrange),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditAdvanceScreen(transaction: advance),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
