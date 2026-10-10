"""Regenerate the checked-in Xcode project. Python standard library only."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "TrainLog.xcodeproj"

def ident(value):
    return hashlib.sha1(value.encode()).hexdigest()[:24].upper()

def quote(value):
    return json.dumps(str(value), ensure_ascii=False)

objects = {}
def put(key, isa, body):
    objects[ident(key)] = f"isa = {isa}; {body}"
    return ident(key)

def ref(path, kind):
    return put("file:" + path, "PBXFileReference", f"lastKnownFileType = {kind}; path = {quote(path)}; sourceTree = SOURCE_ROOT;")

def refs(values):
    return "(" + ", ".join(values) + ("," if values else "") + ")"

def settings(value):
    return "{ " + " ".join(f"{k} = {quote(v)};" for k, v in value.items()) + " }"

package = put("core-package", "XCLocalSwiftPackageReference", "relativePath = Packages/TrainLogCore;")
source_groups = []
product_refs = []
target_ids = []
configs = []
for target, folder, product, product_type in [
    ("TrainLog", "TrainLog", "TrainLog.app", "com.apple.product-type.application"),
    ("TrainLogTests", "TrainLogTests", "TrainLogTests.xctest", "com.apple.product-type.bundle.unit-test"),
    ("TrainLogUITests", "TrainLogUITests", "TrainLogUITests.xctest", "com.apple.product-type.bundle.ui-testing"),
]:
    children, sources, resources, frameworks = [], [], [], []
    for path in sorted((ROOT / folder).rglob("*.swift")):
        relative = path.relative_to(ROOT).as_posix()
        file_id = ref(relative, "sourcecode.swift")
        children.append(file_id)
        sources.append(put("build:" + relative, "PBXBuildFile", f"fileRef = {file_id};"))
    if target == "TrainLog":
        for resource, kind in [("TrainLog/Resources/Assets.xcassets", "folder.assetcatalog"), ("TrainLog/Resources/PrivacyInfo.xcprivacy", "text.xml")]:
            file_id = ref(resource, kind); children.append(file_id)
            resources.append(put("build:" + resource, "PBXBuildFile", f"fileRef = {file_id};"))
        children.append(ref("TrainLog/Resources/Info.plist", "text.plist.xml"))
    source_groups.append(put("group:" + target, "PBXGroup", f"children = {refs(children)}; name = {target}; sourceTree = \"<group>\";"))
    product_ref = put("product:" + target, "PBXFileReference", f"explicitFileType = {'wrapper.application' if target == 'TrainLog' else 'wrapper.cfbundle'}; includeInIndex = 0; path = {product}; sourceTree = BUILT_PRODUCTS_DIR;")
    product_refs.append(product_ref)
    dependencies, packages = [], []
    if target != "TrainLogUITests":
        dependency = put("package-product:" + target, "XCSwiftPackageProductDependency", f"package = {package}; productName = TrainLogCore;")
        packages.append(dependency)
        frameworks.append(put("link-core:" + target, "PBXBuildFile", f"productRef = {dependency};"))
    if target != "TrainLog":
        proxy = put("proxy:" + target, "PBXContainerItemProxy", f"containerPortal = {ident('project')}; proxyType = 1; remoteGlobalIDString = {ident('target:TrainLog')}; remoteInfo = TrainLog;")
        dependencies.append(put("dependency:" + target, "PBXTargetDependency", f"target = {ident('target:TrainLog')}; targetProxy = {proxy};"))
    phases = []
    for name, isa, files in [("Sources", "PBXSourcesBuildPhase", sources), ("Frameworks", "PBXFrameworksBuildPhase", frameworks), ("Resources", "PBXResourcesBuildPhase", resources)]:
        phases.append(put(f"phase:{target}:{name}", isa, f"buildActionMask = 2147483647; files = {refs(files)}; runOnlyForDeploymentPostprocessing = 0;"))
    config_ids = []
    for name in ["Debug", "Release"]:
        values = {"PRODUCT_BUNDLE_IDENTIFIER": "com.trainlog.personal" + ("" if target == "TrainLog" else "." + target), "PRODUCT_NAME": "$(TARGET_NAME)", "SWIFT_VERSION": "5.0", "IPHONEOS_DEPLOYMENT_TARGET": "18.0", "TARGETED_DEVICE_FAMILY": "1", "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "", "SWIFT_STRICT_CONCURRENCY": "targeted", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks"}
        if target == "TrainLog":
            values.update({"INFOPLIST_FILE": "TrainLog/Resources/Info.plist", "GENERATE_INFOPLIST_FILE": "NO", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor", "MARKETING_VERSION": "1.0", "CURRENT_PROJECT_VERSION": "1", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO", "ENABLE_PREVIEWS": "YES"})
        else:
            values.update({"GENERATE_INFOPLIST_FILE": "YES"})
            if target == "TrainLogTests":
                values.update({"BUNDLE_LOADER": "$(TEST_HOST)", "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/TrainLog.app/TrainLog"})
            else:
                values.update({"TEST_TARGET_NAME": "TrainLog"})
        values["ONLY_ACTIVE_ARCH"] = "YES" if name == "Debug" else "NO"
        config_ids.append(put(f"config:{target}:{name}", "XCBuildConfiguration", f"buildSettings = {settings(values)}; name = {name};"))
    config_list = put("configs:" + target, "XCConfigurationList", f"buildConfigurations = {refs(config_ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
    target_ids.append(put("target:" + target, "PBXNativeTarget", f"buildConfigurationList = {config_list}; buildPhases = {refs(phases)}; buildRules = (); dependencies = {refs(dependencies)}; name = {target}; packageProductDependencies = {refs(packages)}; productName = {target}; productReference = {product_ref}; productType = {quote(product_type)};"))

products = put("products", "PBXGroup", f"children = {refs(product_refs)}; name = Products; sourceTree = \"<group>\";")
docs = put("docs", "PBXGroup", f"children = {refs([ref('README.md', 'net.daringfireball.markdown')])}; name = Documentation; sourceTree = \"<group>\";")
main_group = put("main-group", "PBXGroup", f"children = {refs(source_groups + [docs, products])}; sourceTree = \"<group>\";")
for name in ["Debug", "Release"]:
    values = {"SDKROOT": "iphoneos", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "SWIFT_VERSION": "5.0", "IPHONEOS_DEPLOYMENT_TARGET": "18.0", "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES", "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE", "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if name == "Debug" else "-O", "DEBUG_INFORMATION_FORMAT": "dwarf" if name == "Debug" else "dwarf-with-dsym", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)" if name == "Debug" else "$(inherited)", "ENABLE_TESTABILITY": "YES" if name == "Debug" else "NO"}
    configs.append(put("project-config:" + name, "XCBuildConfiguration", f"buildSettings = {settings(values)}; name = {name};"))
config_list = put("project-configs", "XCConfigurationList", f"buildConfigurations = {refs(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
put("project", "PBXProject", f"attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }}; buildConfigurationList = {config_list}; compatibilityVersion = \"Xcode 15.0\"; developmentRegion = zh_CN; hasScannedForEncodings = 0; knownRegions = (zh_CN, en, Base); mainGroup = {main_group}; packageReferences = ({package},); productRefGroup = {products}; projectDirPath = \"\"; projectRoot = \"\"; targets = {refs(target_ids)};")
PROJECT.mkdir(exist_ok=True)
content = "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 60;\n\tobjects = {\n"
content += "\n".join(f"\t\t{key} = {{ {value} }};" for key, value in sorted(objects.items()))
content += f"\n\t}};\n\trootObject = {ident('project')};\n}}\n"
(PROJECT / "project.pbxproj").write_text(content, encoding="utf-8")

def buildable(target):
    suffix = ".app" if target == "TrainLog" else ".xctest"
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target:" + target)}" BuildableName="{target + suffix}" BlueprintName="{target}" ReferencedContainer="container:TrainLog.xcodeproj"/>'

scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable("TrainLog")}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables><TestableReference skipped="NO" parallelizable="NO">{buildable("TrainLogTests")}</TestableReference><TestableReference skipped="NO" parallelizable="NO">{buildable("TrainLogUITests")}</TestableReference></Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="NO">
    <BuildableProductRunnable runnableDebuggingMode="0">{buildable("TrainLog")}</BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable("TrainLog")}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / "TrainLog.xcscheme").write_text(scheme, encoding="utf-8")
workspace = PROJECT / "project.xcworkspace"
workspace.mkdir(exist_ok=True)
(workspace / "contents.xcworkspacedata").write_text('<?xml version="1.0" encoding="UTF-8"?><Workspace version="1.0"><FileRef location="self:"/></Workspace>\n', encoding="utf-8")
print(f"Generated {len(objects)} project objects and shared TrainLog scheme.")

