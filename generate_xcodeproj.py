import os
import hashlib

def gen_uuid(name: str) -> str:
    # 24-char hex string
    h = hashlib.md5(name.encode('utf-8')).hexdigest()[:24].upper()
    return h

# Scan all files inside ios/Zev
files_list = []
base_dir = os.path.join("ios", "Zev")

for root, dirs, files in os.walk(base_dir):
    for f in sorted(files):
        rel_path = os.path.relpath(os.path.join(root, f), base_dir).replace('\\', '/')
        if rel_path.endswith('.swift'):
            files_list.append((rel_path, "sourcecode.swift"))
        elif rel_path.endswith('.plist'):
            files_list.append((rel_path, "text.plist.xml"))

files_list = sorted(files_list, key=lambda x: x[0])

proj_id = gen_uuid("Project_Zev")
target_id = gen_uuid("Target_Zev")
sources_phase_id = gen_uuid("Sources_Phase")
frameworks_phase_id = gen_uuid("Frameworks_Phase")
resources_phase_id = gen_uuid("Resources_Phase")
main_group_id = gen_uuid("Main_Group")
products_group_id = gen_uuid("Products_Group")
zev_group_id = gen_uuid("Zev_Group")
product_ref_id = gen_uuid("Product_Ref_Zev_App")
cfg_list_proj_id = gen_uuid("CfgList_Proj")
cfg_list_target_id = gen_uuid("CfgList_Target")
cfg_proj_debug = gen_uuid("Cfg_Proj_Debug")
cfg_proj_release = gen_uuid("Cfg_Proj_Release")
cfg_target_debug = gen_uuid("Cfg_Target_Debug")
cfg_target_release = gen_uuid("Cfg_Target_Release")

# Subgroups
subgroups = {
    "App": gen_uuid("Group_App"),
    "Config": gen_uuid("Group_Config"),
    "Models": gen_uuid("Group_Models"),
    "Resources": gen_uuid("Group_Resources"),
    "Services": gen_uuid("Group_Services"),
    "ViewModels": gen_uuid("Group_ViewModels"),
    "Views": gen_uuid("Group_Views"),
    "Views/Auth": gen_uuid("Group_Views_Auth"),
    "Views/Components": gen_uuid("Group_Views_Components"),
    "Views/Game": gen_uuid("Group_Views_Game"),
    "Views/Main": gen_uuid("Group_Views_Main"),
    "Views/Onboarding": gen_uuid("Group_Views_Onboarding"),
    "Views/Profile": gen_uuid("Group_Views_Profile"),
}

build_files = []
file_refs = []
sources_entries = []
resources_entries = []

file_info_map = {}

for rel_path, ftype in files_list:
    fname = os.path.basename(rel_path)
    file_ref_id = gen_uuid("FileRef_" + rel_path)
    build_file_id = gen_uuid("BuildFile_" + rel_path)
    
    file_refs.append(f'\t\t{file_ref_id} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{fname}"; sourceTree = "<group>"; }};')
    
    if ftype == "sourcecode.swift":
        build_files.append(f'\t\t{build_file_id} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {fname} */; }};')
        sources_entries.append(f'\t\t\t\t{build_file_id} /* {fname} in Sources */,')
    elif ftype == "text.plist.xml":
        pass

    file_info_map[rel_path] = (file_ref_id, fname)

# Build Groups structure
group_children = {k: [] for k in subgroups}

for rel_path, _ in files_list:
    ref_id, fname = file_info_map[rel_path]
    parts = rel_path.split('/')
    if len(parts) == 2:
        folder = parts[0]
        if folder in group_children:
            group_children[folder].append(f'\t\t\t\t{ref_id} /* {fname} */,')
    elif len(parts) == 3:
        subfolder = f"{parts[0]}/{parts[1]}"
        if subfolder in group_children:
            group_children[subfolder].append(f'\t\t\t\t{ref_id} /* {fname} */,')

views_subgroups = [
    f'\t\t\t\t{subgroups["Views/Auth"]} /* Auth */,',
    f'\t\t\t\t{subgroups["Views/Components"]} /* Components */,',
    f'\t\t\t\t{subgroups["Views/Game"]} /* Game */,',
    f'\t\t\t\t{subgroups["Views/Main"]} /* Main */,',
    f'\t\t\t\t{subgroups["Views/Onboarding"]} /* Onboarding */,',
    f'\t\t\t\t{subgroups["Views/Profile"]} /* Profile */,',
]

top_level_subgroups = [
    f'\t\t\t\t{subgroups["App"]} /* App */,',
    f'\t\t\t\t{subgroups["Config"]} /* Config */,',
    f'\t\t\t\t{subgroups["Models"]} /* Models */,',
    f'\t\t\t\t{subgroups["Resources"]} /* Resources */,',
    f'\t\t\t\t{subgroups["Services"]} /* Services */,',
    f'\t\t\t\t{subgroups["ViewModels"]} /* ViewModels */,',
    f'\t\t\t\t{subgroups["Views"]} /* Views */,',
]

pbx_content = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t{product_ref_id} /* Zev.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Zev.app; sourceTree = BUILT_PRODUCTS_DIR; }};
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{frameworks_phase_id} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{main_group_id} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{zev_group_id} /* Zev */,
\t\t\t\t{products_group_id} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{products_group_id} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{product_ref_id} /* Zev.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{zev_group_id} /* Zev */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(top_level_subgroups)}
\t\t\t);
\t\t\tpath = Zev;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["App"]} /* App */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["App"])}
\t\t\t);
\t\t\tpath = App;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Config"]} /* Config */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["Config"])}
\t\t\t);
\t\t\tpath = Config;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Models"]} /* Models */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["Models"])}
\t\t\t);
\t\t\tpath = Models;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Resources"]} /* Resources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["Resources"])}
\t\t\t);
\t\t\tpath = Resources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Services"]} /* Services */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["Services"])}
\t\t\t);
\t\t\tpath = Services;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["ViewModels"]} /* ViewModels */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["ViewModels"])}
\t\t\t);
\t\t\tpath = ViewModels;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Views"]} /* Views */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(views_subgroups)}
\t\t\t);
\t\t\tpath = Views;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Views/Auth"]} /* Auth */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["Views/Auth"])}
\t\t\t);
\t\t\tpath = Auth;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Views/Components"]} /* Components */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["Views/Components"])}
\t\t\t);
\t\t\tpath = Components;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Views/Game"]} /* Game */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["Views/Game"])}
\t\t\t);
\t\t\tpath = Game;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Views/Main"]} /* Main */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["Views/Main"])}
\t\t\t);
\t\t\tpath = Main;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Views/Onboarding"]} /* Onboarding */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["Views/Onboarding"])}
\t\t\t);
\t\t\tpath = Onboarding;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{subgroups["Views/Profile"]} /* Profile */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(group_children["Views/Profile"])}
\t\t\t);
\t\t\tpath = Profile;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_id} /* Zev */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {cfg_list_target_id} /* Build configuration list for PBXNativeTarget "Zev" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_phase_id} /* Sources */,
\t\t\t\t{frameworks_phase_id} /* Frameworks */,
\t\t\t\t{resources_phase_id} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = Zev;
\t\t\tproductName = Zev;
\t\t\tproductReference = {product_ref_id} /* Zev.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{proj_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1540;
\t\t\t\tLastUpgradeCheck = 1540;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {cfg_list_proj_id} /* Build configuration list for PBXProject "Zev" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group_id};
\t\t\tproductRefGroup = {products_group_id} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target_id} /* Zev */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase_id} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_phase_id} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(sources_entries)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{cfg_proj_debug} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{cfg_proj_release} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{cfg_target_debug} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = Zev/Resources/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.zev.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{cfg_target_release} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = Zev/Resources/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.zev.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{cfg_list_proj_id} /* Build configuration list for PBXProject "Zev" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{cfg_proj_debug} /* Debug */,
\t\t\t\t{cfg_proj_release} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{cfg_list_target_id} /* Build configuration list for PBXNativeTarget "Zev" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{cfg_target_debug} /* Debug */,
\t\t\t\t{cfg_target_release} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {proj_id} /* Project object */;
}}
"""

out_dir = os.path.join("ios", "Zev.xcodeproj")
os.makedirs(out_dir, exist_ok=True)
pbx_path = os.path.join(out_dir, "project.pbxproj")

with open(pbx_path, "w", encoding="utf-8") as f:
    f.write(pbx_content)

# Shared scheme
scheme_dir = os.path.join(out_dir, "xcshareddata", "xcschemes")
os.makedirs(scheme_dir, exist_ok=True)
scheme_path = os.path.join(scheme_dir, "Zev.xcscheme")

scheme_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1540"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "Zev.app"
               BlueprintName = "Zev"
               ReferencedContainer = "container:Zev.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Release"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "Zev.app"
            BlueprintName = "Zev"
            ReferencedContainer = "container:Zev.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "Zev.app"
            BlueprintName = "Zev"
            ReferencedContainer = "container:Zev.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

with open(scheme_path, "w", encoding="utf-8") as f:
    f.write(scheme_content)

print(f"Generated Zev.xcodeproj with {len(files_list)} files and shared scheme successfully!")
