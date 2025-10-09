// lib/screens/service_technique/historic_interventions_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/screens/service_technique/intervention_history_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/installation_history_list_page.dart';
import 'package:boitex_info_app/screens/administration/mission_history_list_page.dart';
import 'package:boitex_info_app/screens/service_technique/sav_ticket_history_page.dart';
import 'package:boitex_info_app/screens/service_technique/completed_replacement_list_page.dart';
import 'package:boitex_info_app/screens/administration/livraison_history_page.dart';


class HistoricInterventionsPage extends StatelessWidget {
  final String serviceType;

  const HistoricInterventionsPage({super.key, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Historique - $serviceType"),
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ... (The other cards remain the same)
          _buildHistoryCategoryCard(
            context: context,
            title: 'Historique des Interventions',
            subtitle: 'Consulter toutes les interventions terminées',
            icon: Icons.schedule,
            color: Colors.blue,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InterventionHistoryListPage(serviceType: serviceType),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          _buildHistoryCategoryCard(
            context: context,
            title: 'Historique des Installations',
            subtitle: 'Consulter toutes les installations terminées',
            icon: Icons.router_outlined,
            color: const Color(0xFF3b82f6),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InstallationHistoryListPage(serviceType: serviceType),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          _buildHistoryCategoryCard(
            context: context,
            title: 'Historique des Missions',
            subtitle: 'Consulter toutes les missions terminées',
            icon: Icons.assignment_turned_in_outlined,
            color: Colors.purple,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MissionHistoryListPage(serviceType: serviceType),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          _buildHistoryCategoryCard(
            context: context,
            title: 'Historique des Tickets SAV',
            subtitle: 'Consulter tous les tickets retournés',
            icon: Icons.support_agent_outlined,
            color: Colors.orange,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SavTicketHistoryPage(serviceType: serviceType),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // ✅ CHANGED: Now passes the serviceType to the next page
          _buildHistoryCategoryCard(
            context: context,
            title: 'Historique des Remplacements',
            subtitle: 'Consulter tous les remplacements effectués',
            icon: Icons.sync_alt_outlined,
            color: Colors.red,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CompletedReplacementListPage(serviceType: serviceType),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          _buildHistoryCategoryCard(
            context: context,
            title: 'Historique des Livraisons',
            subtitle: 'Consulter toutes les livraisons effectuées',
            icon: Icons.local_shipping_outlined,
            color: Colors.brown,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LivraisonHistoryPage(serviceType: serviceType),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCategoryCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16.0),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}