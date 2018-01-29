diff --git drivers/firmware/psci.c drivers/firmware/psci.c
index 2c82942..563cc2f 100644
--- drivers/firmware/psci.c
+++ drivers/firmware/psci.c
@@ -214,9 +214,12 @@ static void psci_sys_reset(enum reboot_mode reboot_mode, const char *cmd)
 	u32 reason = 0;
 
 #if defined(CONFIG_ARCH_S5P6818) || defined(CONFIG_ARCH_S5P4418)
-#define RECOVERY_SIGNATURE      (0x52455343)    /* (ASCII) : R.E.S.C */
+#define RECOVERY_SIGNATURE		(0x52455343)    /* (ASCII) : R.E.S.C */
+#define CHARGING_SIGNATURE		(0x43484152)    /* (ASCII) : C.H.A.G */
 	if (cmd != NULL && !strcmp(cmd, "recovery"))
 		reason = RECOVERY_SIGNATURE;
+	else if (cmd != NULL && !strcmp(cmd, "charging"))
+		reason = CHARGING_SIGNATURE;
 #endif
 	invoke_psci_fn(PSCI_0_2_FN_SYSTEM_RESET, reason, 0, 0);
 }
