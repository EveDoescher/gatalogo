# Inventário estático de qualidade

Gerado por `scripts/audit_quality.py` na API. Candidatos exigem revisão; ausência de referência não prova inutilidade.

Arquivos versionados ou novos (respeitando .gitignore): 3072. Fontes Python/Dart: 330.

## Distribuição das fontes

| Diretório | Arquivos | Linhas |
|---|---:|---:|
| .agents/skills/brand/scripts/tests | 1 | 88 |
| .agents/skills/design-system/scripts | 6 | 2184 |
| .agents/skills/design-system/scripts/tests | 1 | 52 |
| .agents/skills/design/scripts/cip | 4 | 1253 |
| .agents/skills/design/scripts/icon | 1 | 487 |
| .agents/skills/design/scripts/logo | 3 | 1058 |
| .agents/skills/design/scripts/logo/tests | 1 | 288 |
| .agents/skills/ui-styling/scripts | 2 | 781 |
| .agents/skills/ui-styling/scripts/tests | 2 | 660 |
| .agents/skills/ui-ux-pro-max/scripts | 5 | 4031 |
| .agents/skills/ui-ux-pro-max/scripts/tests | 13 | 2556 |
| lib | 2 | 427 |
| lib/config | 1 | 39 |
| lib/controllers | 4 | 744 |
| lib/data | 3 | 469 |
| lib/data/repositories | 4 | 533 |
| lib/formatters | 1 | 66 |
| lib/game | 27 | 6608 |
| lib/models | 11 | 1404 |
| lib/pages | 33 | 24511 |
| lib/services | 28 | 5570 |
| lib/stores | 3 | 1433 |
| lib/theme | 1 | 747 |
| lib/widgets | 53 | 12241 |
| test | 77 | 14873 |
| test/support | 3 | 527 |
| tool | 40 | 4143 |

## Fontes com mais de 500 linhas

| Arquivo | Linhas |
|---|---:|
| `lib/game/habitat_game.dart` | 2013 |
| `lib/pages/habitat_page.dart` | 1753 |
| `lib/pages/conversation_page.dart` | 1692 |
| `.agents/skills/ui-ux-pro-max/scripts/design_system.py` | 1643 |
| `lib/pages/settings_page.dart` | 1638 |
| `test/quintal_production_visual_test.dart` | 1584 |
| `lib/game/quintal_production_scene.dart` | 1503 |
| `lib/pages/library_page.dart` | 1400 |
| `lib/pages/friends_page.dart` | 1360 |
| `lib/widgets/quintal_object_actions.dart` | 1290 |
| `lib/pages/auth_page.dart` | 1209 |
| `lib/pages/cat_details_page.dart` | 1197 |
| `.agents/skills/ui-ux-pro-max/scripts/validate_data.py` | 1095 |
| `test/quintal_object_actions_test.dart` | 1075 |
| `lib/pages/social_page.dart` | 1046 |
| `.agents/skills/ui-ux-pro-max/scripts/core.py` | 993 |
| `lib/pages/my_cats_page.dart` | 988 |
| `lib/pages/home_page.dart` | 973 |
| `test/visual_validation_capture_test.dart` | 954 |
| `lib/pages/profile_page.dart` | 868 |
| `lib/stores/cat_store.dart` | 868 |
| `lib/services/habitat_service.dart` | 810 |
| `lib/pages/location_page.dart` | 807 |
| `lib/pages/capture_page.dart` | 806 |
| `.agents/skills/design-system/scripts/generate-slide.py` | 770 |
| `.agents/skills/design/scripts/logo/generate.py` | 769 |
| `lib/pages/public_profile_page.dart` | 748 |
| `lib/theme/app_theme.dart` | 747 |
| `lib/pages/cat_gallery_page.dart` | 702 |
| `lib/pages/discovery_result_page.dart` | 666 |
| `lib/pages/clues_page.dart` | 656 |
| `lib/widgets/post_composer.dart` | 644 |
| `lib/pages/quintal_game_page.dart` | 614 |
| `lib/widgets/chat_message_bubble.dart` | 602 |
| `lib/pages/clue_detail_page.dart` | 598 |
| `lib/widgets/cat_analysis_card.dart` | 597 |
| `lib/pages/create_missing_report_page.dart` | 586 |
| `lib/controllers/conversation_controller.dart` | 585 |
| `lib/widgets/game_components.dart` | 566 |
| `lib/pages/missing_report_detail_page.dart` | 564 |
| `lib/widgets/botanical_scene.dart` | 551 |
| `lib/pages/habitat_shop_page.dart` | 550 |

## Dependências entre rotas Python


## Corpos de funções Python idênticos


## Dart fora do grafo de lib/main.dart

Inclui componentes acessíveis somente por testes ou ferramentas. Confirmar antes de remover.


## Arquivos rastreados que exigem classificação


## Inventário completo das fontes

| Arquivo | Linhas |
|---|---:|
| `.agents/skills/brand/scripts/tests/test_sync_brand_to_tokens.py` | 88 |
| `.agents/skills/design-system/scripts/fetch-background.py` | 339 |
| `.agents/skills/design-system/scripts/generate-slide.py` | 770 |
| `.agents/skills/design-system/scripts/html-token-validator.py` | 359 |
| `.agents/skills/design-system/scripts/search-slides.py` | 228 |
| `.agents/skills/design-system/scripts/slide-token-validator.py` | 35 |
| `.agents/skills/design-system/scripts/slide_search_core.py` | 453 |
| `.agents/skills/design-system/scripts/tests/test_validate_tokens.py` | 52 |
| `.agents/skills/design/scripts/cip/core.py` | 215 |
| `.agents/skills/design/scripts/cip/generate.py` | 487 |
| `.agents/skills/design/scripts/cip/render-html.py` | 424 |
| `.agents/skills/design/scripts/cip/search.py` | 127 |
| `.agents/skills/design/scripts/icon/generate.py` | 487 |
| `.agents/skills/design/scripts/logo/core.py` | 175 |
| `.agents/skills/design/scripts/logo/generate.py` | 769 |
| `.agents/skills/design/scripts/logo/search.py` | 114 |
| `.agents/skills/design/scripts/logo/tests/test_generate.py` | 288 |
| `.agents/skills/ui-styling/scripts/shadcn_add.py` | 308 |
| `.agents/skills/ui-styling/scripts/tailwind_config_gen.py` | 473 |
| `.agents/skills/ui-styling/scripts/tests/test_shadcn_add.py` | 266 |
| `.agents/skills/ui-styling/scripts/tests/test_tailwind_config_gen.py` | 394 |
| `.agents/skills/ui-ux-pro-max/scripts/core.py` | 993 |
| `.agents/skills/ui-ux-pro-max/scripts/design_system.py` | 1643 |
| `.agents/skills/ui-ux-pro-max/scripts/reasoning_contract.py` | 123 |
| `.agents/skills/ui-ux-pro-max/scripts/search.py` | 177 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_catalog_refresh.py` | 354 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_catalog_summary_line_endings.py` | 78 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_core.py` | 343 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_core_data_quality.py` | 198 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_data_contracts.py` | 421 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_design_system_mode.py` | 189 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_design_system_stack.py` | 61 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_native_desktop_stack_freshness.py` | 176 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_relevance_evaluator.py` | 182 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_skill_script_paths.py` | 82 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_style_taxonomy.py` | 175 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_text_layout_resilience.py` | 120 |
| `.agents/skills/ui-ux-pro-max/scripts/tests/test_web_stack_freshness.py` | 177 |
| `.agents/skills/ui-ux-pro-max/scripts/validate_data.py` | 1095 |
| `lib/app.dart` | 417 |
| `lib/config/api_config.dart` | 39 |
| `lib/controllers/account_activity_controller.dart` | 49 |
| `lib/controllers/cat_details_controller.dart` | 60 |
| `lib/controllers/conversation_controller.dart` | 585 |
| `lib/controllers/habitat_interaction_state.dart` | 50 |
| `lib/data/cat_database.dart` | 191 |
| `lib/data/cat_database_schema.dart` | 244 |
| `lib/data/habitat_repository.dart` | 34 |
| `lib/data/repositories/catalog_repository.dart` | 252 |
| `lib/data/repositories/habitat_cache_repository.dart` | 73 |
| `lib/data/repositories/reference_photo_repository.dart` | 81 |
| `lib/data/repositories/sync_metadata_repository.dart` | 127 |
| `lib/formatters/app_dates.dart` | 66 |
| `lib/game/habitat_camera.dart` | 134 |
| `lib/game/habitat_cat_animations.dart` | 188 |
| `lib/game/habitat_cat_coat.dart` | 68 |
| `lib/game/habitat_cat_motion.dart` | 178 |
| `lib/game/habitat_game.dart` | 2013 |
| `lib/game/habitat_interactions.dart` | 143 |
| `lib/game/habitat_palette.dart` | 65 |
| `lib/game/habitat_path_style.dart` | 16 |
| `lib/game/habitat_river_palette.dart` | 36 |
| `lib/game/habitat_scene_selection.dart` | 12 |
| `lib/game/habitat_sprites.dart` | 448 |
| `lib/game/habitat_visitor_sprites.dart` | 48 |
| `lib/game/habitat_visits.dart` | 426 |
| `lib/game/habitat_world.dart` | 383 |
| `lib/game/quintal_action_effect.dart` | 210 |
| `lib/game/quintal_construction_preview.dart` | 21 |
| `lib/game/quintal_cooking_motion.dart` | 42 |
| `lib/game/quintal_game_motion.dart` | 10 |
| `lib/game/quintal_garden_motion.dart` | 37 |
| `lib/game/quintal_play_field.dart` | 78 |
| `lib/game/quintal_play_lane.dart` | 69 |
| `lib/game/quintal_play_motion.dart` | 75 |
| `lib/game/quintal_play_result.dart` | 19 |
| `lib/game/quintal_production_scene.dart` | 1503 |
| `lib/game/quintal_resident_motion.dart` | 277 |
| `lib/game/quintal_scene_target.dart` | 25 |
| `lib/game/quintal_timed_progress.dart` | 84 |
| `lib/main.dart` | 10 |
| `lib/models/auth_session.dart` | 15 |
| `lib/models/cat.dart` | 347 |
| `lib/models/cat_analysis.dart` | 162 |
| `lib/models/cat_collection.dart` | 28 |
| `lib/models/cat_reference_photo.dart` | 44 |
| `lib/models/chat_message.dart` | 186 |
| `lib/models/conversation_summary.dart` | 109 |
| `lib/models/gamification.dart` | 210 |
| `lib/models/habitat.dart` | 153 |
| `lib/models/missing_poster.dart` | 113 |
| `lib/models/quintal_snapshot.dart` | 37 |
| `lib/pages/auth_page.dart` | 1209 |
| `lib/pages/capture_page.dart` | 806 |
| `lib/pages/cat_details_page.dart` | 1197 |
| `lib/pages/cat_gallery_page.dart` | 702 |
| `lib/pages/challenges_page.dart` | 88 |
| `lib/pages/clue_detail_page.dart` | 598 |
| `lib/pages/clues_page.dart` | 656 |
| `lib/pages/community_posters_page.dart` | 318 |
| `lib/pages/conversation_page.dart` | 1692 |
| `lib/pages/create_missing_report_page.dart` | 586 |
| `lib/pages/discovery_result_page.dart` | 666 |
| `lib/pages/experience_settings_page.dart` | 197 |
| `lib/pages/friends_page.dart` | 1360 |
| `lib/pages/habitat_help_page.dart` | 135 |
| `lib/pages/habitat_page.dart` | 1753 |
| `lib/pages/habitat_shop_page.dart` | 550 |
| `lib/pages/home_page.dart` | 973 |
| `lib/pages/inbox_page.dart` | 447 |
| `lib/pages/journey_page.dart` | 333 |
| `lib/pages/library_page.dart` | 1400 |
| `lib/pages/location_page.dart` | 807 |
| `lib/pages/missing_cat_poster_page.dart` | 245 |
| `lib/pages/missing_cats_page.dart` | 231 |
| `lib/pages/missing_map_consolidated_page.dart` | 430 |
| `lib/pages/missing_report_detail_page.dart` | 564 |
| `lib/pages/my_cats_page.dart` | 988 |
| `lib/pages/notifications_page.dart` | 484 |
| `lib/pages/profile_page.dart` | 868 |
| `lib/pages/public_profile_page.dart` | 748 |
| `lib/pages/quintal_game_page.dart` | 614 |
| `lib/pages/result_history_page.dart` | 182 |
| `lib/pages/settings_page.dart` | 1638 |
| `lib/pages/social_page.dart` | 1046 |
| `lib/services/analysis_api_service.dart` | 149 |
| `lib/services/auth_api_service.dart` | 264 |
| `lib/services/authenticated_api_client.dart` | 76 |
| `lib/services/cat_preflight_service.dart` | 355 |
| `lib/services/cat_sharing_service.dart` | 192 |
| `lib/services/catalog_sync_coordinator.dart` | 84 |
| `lib/services/catalog_sync_service.dart` | 410 |
| `lib/services/experience_service.dart` | 151 |
| `lib/services/favorites_manager.dart` | 126 |
| `lib/services/gamification_service.dart` | 137 |
| `lib/services/habitat_care.dart` | 118 |
| `lib/services/habitat_catalog.g.dart` | 467 |
| `lib/services/habitat_encounters.dart` | 52 |
| `lib/services/habitat_layout.dart` | 135 |
| `lib/services/habitat_navigation.dart` | 8 |
| `lib/services/habitat_service.dart` | 810 |
| `lib/services/image_compression_service.dart` | 46 |
| `lib/services/location_service.dart` | 191 |
| `lib/services/missing_poster_export.dart` | 305 |
| `lib/services/product_api_service.dart` | 88 |
| `lib/services/progress_service.dart` | 173 |
| `lib/services/push_notification_service.dart` | 191 |
| `lib/services/quintal_cat_meal.dart` | 91 |
| `lib/services/quintal_inventory.dart` | 87 |
| `lib/services/quintal_production.dart` | 131 |
| `lib/services/social_api_service.dart` | 376 |
| `lib/services/vision_api_service.dart` | 113 |
| `lib/services/websocket_service.dart` | 244 |
| `lib/stores/cat_store.dart` | 868 |
| `lib/stores/notification_store.dart` | 147 |
| `lib/stores/session_store.dart` | 418 |
| `lib/theme/app_theme.dart` | 747 |
| `lib/widgets/active_search_proximity_card.dart` | 500 |
| `lib/widgets/app_header_actions.dart` | 137 |
| `lib/widgets/app_loading_screen.dart` | 45 |
| `lib/widgets/app_widgets.dart` | 369 |
| `lib/widgets/avatar_choice_sheet.dart` | 78 |
| `lib/widgets/botanical_scene.dart` | 551 |
| `lib/widgets/cat_analysis_card.dart` | 597 |
| `lib/widgets/cat_coat_color_item.dart` | 118 |
| `lib/widgets/cat_history_photos.dart` | 54 |
| `lib/widgets/cat_name_dialog.dart` | 85 |
| `lib/widgets/chat_message_bubble.dart` | 602 |
| `lib/widgets/community_post_card.dart` | 178 |
| `lib/widgets/conversation_composer.dart` | 293 |
| `lib/widgets/feed_loading_placeholder.dart` | 56 |
| `lib/widgets/game_components.dart` | 566 |
| `lib/widgets/gatalogo_components.dart` | 478 |
| `lib/widgets/gatalogo_gamification.dart` | 315 |
| `lib/widgets/habitat_care_sheet.dart` | 145 |
| `lib/widgets/habitat_cat_preview.dart` | 25 |
| `lib/widgets/habitat_coin_badge.dart` | 37 |
| `lib/widgets/habitat_ground_tools.dart` | 65 |
| `lib/widgets/habitat_hud.dart` | 110 |
| `lib/widgets/habitat_object_balloon.dart` | 344 |
| `lib/widgets/habitat_reward_reveal.dart` | 55 |
| `lib/widgets/habitat_sprite_preview.dart` | 79 |
| `lib/widgets/illustrated_home_components.dart` | 369 |
| `lib/widgets/inbox_button.dart` | 94 |
| `lib/widgets/milestone_widgets.dart` | 315 |
| `lib/widgets/missing_poster_artwork.dart` | 267 |
| `lib/widgets/post_composer.dart` | 644 |
| `lib/widgets/poster_export_actions.dart` | 134 |
| `lib/widgets/poster_settings_editor.dart` | 387 |
| `lib/widgets/private_clue_photo.dart` | 69 |
| `lib/widgets/profile_qr_dialog.dart` | 194 |
| `lib/widgets/progress_components.dart` | 209 |
| `lib/widgets/quintal_activity_result.dart` | 67 |
| `lib/widgets/quintal_bond_progress.dart` | 111 |
| `lib/widgets/quintal_bottom_tray.dart` | 136 |
| `lib/widgets/quintal_clock_badge.dart` | 70 |
| `lib/widgets/quintal_fishing_arena.dart` | 143 |
| `lib/widgets/quintal_game_action.dart` | 125 |
| `lib/widgets/quintal_hold_control.dart` | 113 |
| `lib/widgets/quintal_inventory_tray.dart` | 449 |
| `lib/widgets/quintal_object_actions.dart` | 1290 |
| `lib/widgets/quintal_outlined_text.dart` | 85 |
| `lib/widgets/quintal_play_arena.dart` | 125 |
| `lib/widgets/quintal_preparation_tile.dart` | 93 |
| `lib/widgets/quintal_production_widgets.dart` | 198 |
| `lib/widgets/quintal_recipe_tile.dart` | 86 |
| `lib/widgets/quintal_return_dialog.dart` | 212 |
| `lib/widgets/quintal_reward_celebration.dart` | 311 |
| `lib/widgets/remote_avatar_image.dart` | 35 |
| `lib/widgets/social_publish_button.dart` | 28 |
| `test/app_dates_test.dart` | 30 |
| `test/architecture_contracts_test.dart` | 96 |
| `test/auth_page_test.dart` | 79 |
| `test/authenticated_api_client_test.dart` | 93 |
| `test/auto_sync_test.dart` | 69 |
| `test/cat_details_page_test.dart` | 156 |
| `test/cat_preflight_service_test.dart` | 49 |
| `test/cat_sharing_service_test.dart` | 122 |
| `test/chat_rescue_test.dart` | 200 |
| `test/conversation_controller_test.dart` | 221 |
| `test/corrections_preview_test.dart` | 115 |
| `test/feed_social_test.dart` | 55 |
| `test/friends_discovery_test.dart` | 94 |
| `test/gamification_service_test.dart` | 106 |
| `test/gamification_test.dart` | 254 |
| `test/habitat_care_sheet_test.dart` | 69 |
| `test/habitat_cat_coat_test.dart` | 150 |
| `test/habitat_game_test.dart` | 334 |
| `test/habitat_interactions_test.dart` | 153 |
| `test/habitat_object_balloon_test.dart` | 68 |
| `test/habitat_page_test.dart` | 206 |
| `test/habitat_service_test.dart` | 474 |
| `test/habitat_visit_capture_test.dart` | 73 |
| `test/habitat_world_test.dart` | 239 |
| `test/home_reference_test.dart` | 281 |
| `test/library_filters_test.dart` | 136 |
| `test/local_database_test.dart` | 69 |
| `test/missing_poster_test.dart` | 155 |
| `test/navigation_background_test.dart` | 80 |
| `test/navigation_levels_test.dart` | 58 |
| `test/notification_store_test.dart` | 119 |
| `test/post_composer_test.dart` | 109 |
| `test/product_api_service_test.dart` | 143 |
| `test/product_flows_test.dart` | 132 |
| `test/product_preview_test.dart` | 63 |
| `test/progress_store_test.dart` | 91 |
| `test/push_notification_service_test.dart` | 181 |
| `test/quintal_action_effect_test.dart` | 96 |
| `test/quintal_bottom_tray_test.dart` | 91 |
| `test/quintal_camera_matrix_test.dart` | 228 |
| `test/quintal_cat_meal_test.dart` | 124 |
| `test/quintal_cooking_motion_test.dart` | 16 |
| `test/quintal_fishing_arena_test.dart` | 41 |
| `test/quintal_game_motion_test.dart` | 39 |
| `test/quintal_game_page_test.dart` | 341 |
| `test/quintal_garden_motion_test.dart` | 46 |
| `test/quintal_garden_visual_test.dart` | 240 |
| `test/quintal_hold_control_test.dart` | 56 |
| `test/quintal_inventory_test.dart` | 272 |
| `test/quintal_kitchen_visual_test.dart` | 294 |
| `test/quintal_live_client_test.dart` | 164 |
| `test/quintal_market_visual_test.dart` | 258 |
| `test/quintal_meals_visual_test.dart` | 398 |
| `test/quintal_notifications_visual_test.dart` | 188 |
| `test/quintal_object_actions_test.dart` | 1075 |
| `test/quintal_orchard_visual_test.dart` | 283 |
| `test/quintal_play_field_test.dart` | 21 |
| `test/quintal_play_lane_test.dart` | 57 |
| `test/quintal_play_motion_test.dart` | 35 |
| `test/quintal_play_result_test.dart` | 40 |
| `test/quintal_production_service_test.dart` | 312 |
| `test/quintal_production_visual_test.dart` | 1584 |
| `test/quintal_rewards_visual_test.dart` | 212 |
| `test/quintal_rewards_widgets_test.dart` | 242 |
| `test/quintal_routines_test.dart` | 134 |
| `test/quintal_timed_progress_test.dart` | 61 |
| `test/quintal_visual_validation_test.dart` | 117 |
| `test/quintal_world_rules_test.dart` | 313 |
| `test/remote_avatar_image_test.dart` | 29 |
| `test/restructure_test.dart` | 322 |
| `test/screen_corrections_test.dart` | 432 |
| `test/session_store_test.dart` | 152 |
| `test/social_publish_visual_test.dart` | 115 |
| `test/social_reference_test.dart` | 192 |
| `test/support/fixture_image_client.dart` | 59 |
| `test/support/habitat_ready.dart` | 36 |
| `test/support/visual_gallery.dart` | 432 |
| `test/theme_and_settings_test.dart` | 154 |
| `test/visual_validation_capture_test.dart` | 954 |
| `test/widget_test.dart` | 23 |
| `tool/build_habitat_lighting.py` | 129 |
| `tool/build_habitat_manifest.py` | 61 |
| `tool/build_habitat_motion_gallery.py` | 64 |
| `tool/build_model_asset_gallery.py` | 137 |
| `tool/build_quintal_action_motion_gallery.py` | 66 |
| `tool/build_quintal_compositions.py` | 188 |
| `tool/build_quintal_crafted_models.py` | 280 |
| `tool/build_quintal_crops_gallery.py` | 50 |
| `tool/build_quintal_garden_motion_gallery.py` | 40 |
| `tool/build_quintal_gate_motion_gallery.py` | 41 |
| `tool/build_quintal_harvest_motion_gallery.py` | 40 |
| `tool/build_quintal_kitchen_motion_gallery.py` | 40 |
| `tool/build_quintal_meals_motion_gallery.py` | 40 |
| `tool/build_quintal_play_motion_gallery.py` | 40 |
| `tool/build_quintal_production_assets.py` | 142 |
| `tool/build_quintal_shelter_motion_gallery.py` | 39 |
| `tool/build_quintal_tools_motion_gallery.py` | 40 |
| `tool/export_habitat_catalog.py` | 44 |
| `tool/generate_journal_audio.py` | 31 |
| `tool/habitat_assets.py` | 62 |
| `tool/habitat_model.py` | 170 |
| `tool/habitat_preview_test.dart` | 415 |
| `tool/quintal_action_tools.py` | 61 |
| `tool/quintal_cozy_crops.py` | 233 |
| `tool/quintal_cozy_models.py` | 389 |
| `tool/quintal_gate_models.py` | 33 |
| `tool/quintal_model_audit.py` | 120 |
| `tool/quintal_model_authoring.py` | 185 |
| `tool/quintal_model_gallery.py` | 96 |
| `tool/quintal_shelter_layers.py` | 18 |
| `tool/recover_habitat_decor.py` | 37 |
| `tool/render_habitat_cat.py` | 91 |
| `tool/render_habitat_decor.py` | 40 |
| `tool/render_habitat_models.py` | 96 |
| `tool/render_quintal_cat_coats.py` | 225 |
| `tool/render_quintal_previews.py` | 47 |
| `tool/render_quintal_residents.py` | 72 |
| `tool/test_habitat_animation.py` | 57 |
| `tool/test_habitat_lighting.py` | 66 |
| `tool/test_quintal_cozy_models.py` | 118 |
