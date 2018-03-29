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
diff --git drivers/gpu/drm/nexell/nx_drm_drv.c drivers/gpu/drm/nexell/nx_drm_drv.c
index 21b0100..2fde067 100644
--- drivers/gpu/drm/nexell/nx_drm_drv.c
+++ drivers/gpu/drm/nexell/nx_drm_drv.c
@@ -23,12 +23,24 @@
 
 #include <linux/of_platform.h>
 #include <linux/component.h>
+#include <linux/sysfs.h>
 
 #include <drm/nexell_drm.h>
 
 #include "nx_drm_drv.h"
 #include "nx_drm_fb.h"
 #include "nx_drm_gem.h"
+#include "s5pxx18/s5pxx18_soc_mlc.h"
+#include "s5pxx18/s5pxx18_soc_gamma.h"
+
+//  mlc_gammatable
+void set_mlc_gamma(int module, int r_gamma, int g_gamma, int b_gamma);
+
+struct nx_mlc_gamma_table_parameter nx_mlc_gammatable;
+static int g_gamma_val[2][3]= {
+				{13,13,13},
+				{13,13,13}
+				};
 
 struct nx_drm_commit {
 	struct drm_device *drm;
@@ -584,11 +596,108 @@ static struct platform_driver nx_drm_drviver = {
 		   .pm	= &nx_drm_pm_ops,
 		   },
 };
+void  set_mlc_gamma(int module, int r_gamma, int g_gamma, int b_gamma)
+{
+
+    struct nx_mlc_gamma_table_parameter *p_nx_mlc_gammatable;
+    u32 i;
+
+    p_nx_mlc_gammatable = &nx_mlc_gammatable;
+
+    for(i=0; i<256; i++) {
+        p_nx_mlc_gammatable->r_table[i] = mlc_gtable[r_gamma-1][i];
+        p_nx_mlc_gammatable->g_table[i] = mlc_gtable[g_gamma-1][i];
+        p_nx_mlc_gammatable->b_table[i] = mlc_gtable[b_gamma-1][i];
+    }
 
+    p_nx_mlc_gammatable->ditherenb   = 0;
+    p_nx_mlc_gammatable->alphaselect = 0;
+    p_nx_mlc_gammatable->yuvgammaenb = 0;
+    p_nx_mlc_gammatable->rgbgammaenb = 0;
+    p_nx_mlc_gammatable->allgammaenb = 1;
+
+    nx_mlc_set_gamma_table( module, 1, p_nx_mlc_gammatable );
+	nx_mlc_set_top_dirty_flag(module);
+}
+
+static ssize_t gamma_show(struct device *pdev,
+        struct device_attribute *attr, char *buf)
+{
+    struct attribute *at = &attr->attr;
+    const char *c;
+	int a;
+
+	c = &at->name[strlen("gamma")];
+	a = simple_strtoul(c, NULL, 10);
+
+	return scnprintf(buf, PAGE_SIZE, "r=%d g=%d b=%d \n",
+			g_gamma_val[a][0],
+			g_gamma_val[a][1],
+			g_gamma_val[a][2]
+			);
+}
+static ssize_t gamma_set(struct device *pdev,
+            struct device_attribute *attr, const char *buf, size_t n)
+{
+    struct attribute *at = &attr->attr;
+	const char *c;
+    int a;
+
+	c = &at->name[strlen("gamma")];
+    a = simple_strtoul(c, NULL, 10);
+
+	sscanf(buf,"%d %d %d", &g_gamma_val[a][0],
+			&g_gamma_val[a][1],
+			&g_gamma_val[a][2]
+			);
+
+	if(!(g_gamma_val[a][0] > MAX_GAMMA) &&
+		!(g_gamma_val[a][1] > MAX_GAMMA) &&
+		!(g_gamma_val[a][2] > MAX_GAMMA))
+		set_mlc_gamma(a, g_gamma_val[a][0],
+				g_gamma_val[a][1],
+				g_gamma_val[a][2]);
+	return n;
+}
+#if 1
+
+static DEVICE_ATTR(gammar0, (S_IRUGO | S_IWUSR | S_IWGRP),
+		gamma_show, gamma_set);
+static DEVICE_ATTR(gammar1, (S_IRUGO | S_IWUSR | S_IWGRP),
+		gamma_show, gamma_set);
+
+/* sys attribte group */
+static struct attribute *gamma_attrs[] = {
+    &dev_attr_gammar0.attr,
+	&dev_attr_gammar1.attr,
+    NULL,
+};
+
+static struct attribute_group attr_group = {
+    .attrs = gamma_attrs,
+};
+#endif
 static int __init nx_drm_init(void)
 {
 	int i;
+#if 1
+	struct kobject *kobj = NULL;
+	int ret = 0;
+
+	/* create attribute interface */
+	kobj = kobject_create_and_add("display", &platform_bus.kobj);
+	if (! kobj) {
+		printk(KERN_ERR "Fail, create kobject for display\n");
+		return -1;
+	}
 
+    ret = sysfs_create_group(kobj, &attr_group);
+    if (ret) {
+        printk(KERN_ERR "Fail, create sysfs group for display\n");
+        kobject_del(kobj);
+        return -1;
+    }
+#endif
 	for (i = 0; i < ARRAY_SIZE(drm_panel_drivers); i++) {
 		struct drm_panel_driver *pn = &drm_panel_drivers[i];
 
@@ -597,6 +706,8 @@ static int __init nx_drm_init(void)
 			pn->init();
 	}
 
+
+
 	return platform_driver_register(&nx_drm_drviver);
 }
 
diff --git drivers/gpu/drm/nexell/s5pxx18/s5pxx18_dev.c drivers/gpu/drm/nexell/s5pxx18/s5pxx18_dev.c
index 03df428..2265251 100644
--- drivers/gpu/drm/nexell/s5pxx18/s5pxx18_dev.c
+++ drivers/gpu/drm/nexell/s5pxx18/s5pxx18_dev.c
@@ -487,6 +487,8 @@ void nx_soc_dp_plane_top_set_bg_color(struct nx_top_plane *top)
 	nx_mlc_set_top_dirty_flag(module);
 }
 
+
+extern void set_mlc_gamma(int module, int r_gamma, int g_gamma, int b_gamma);
 int nx_soc_dp_plane_top_set_enable(struct nx_top_plane *top, bool on)
 {
 	struct nx_plane_layer *layer;
@@ -504,6 +506,9 @@ int nx_soc_dp_plane_top_set_enable(struct nx_top_plane *top, bool on)
 		nx_mlc_set_rgblayer_gamma_enable(module, 0);
 		nx_mlc_set_dither_enable_when_using_gamma(module, 0);
 		nx_mlc_set_gamma_priority(module, 0);
+		/* set default gamma */
+		set_mlc_gamma(module, 13, 13, 13);
+
 		nx_mlc_set_top_power_mode(module, 1);
 		nx_mlc_set_top_sleep_mode(module, 0);
 		nx_mlc_set_mlc_enable(module, 1);
diff --git kernel/reboot.c kernel/reboot.c
index bd30a97..dcdf62c 100644
--- kernel/reboot.c
+++ kernel/reboot.c
@@ -254,6 +254,7 @@ EXPORT_SYMBOL_GPL(kernel_halt);
  *
  *	Shutdown everything and perform a clean system power_off.
  */
+extern int g_bq25895m_online;
 void kernel_power_off(void)
 {
 	kernel_shutdown_prepare(SYSTEM_POWER_OFF);
@@ -263,7 +264,10 @@ void kernel_power_off(void)
 	syscore_shutdown();
 	pr_emerg("Power down\n");
 	kmsg_dump(KMSG_DUMP_POWEROFF);
-	machine_power_off();
+	if(!g_bq25895m_online)
+		machine_power_off();
+	else
+		machine_restart("charging");
 }
 EXPORT_SYMBOL_GPL(kernel_power_off);
 
diff --git kernel/sched/core.c kernel/sched/core.c
index 9307827..e1aad04 100644
--- kernel/sched/core.c
+++ kernel/sched/core.c
@@ -4027,6 +4027,7 @@ recheck:
 				return -EPERM;
 		}
 
+#if 0
 		if (rt_policy(policy)) {
 			unsigned long rlim_rtprio =
 					task_rlimit(p, RLIMIT_RTPRIO);
@@ -4040,6 +4041,7 @@ recheck:
 			    attr->sched_priority > rlim_rtprio)
 				return -EPERM;
 		}
+#endif
 
 		 /*
 		  * Can't set/change SCHED_DEADLINE policy at all for now
