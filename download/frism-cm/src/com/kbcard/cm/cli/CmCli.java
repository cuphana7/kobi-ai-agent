package com.kbcard.cm.cli;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import com.kbcard.cm.util.UtilCm;
import com.kbcard.cm.util.UtilCmData;
import com.kbcard.excption.BizException;

public class CmCli {
    public static void main(String[] args) {
        if (args.length < 1) {
            printError("USAGE_ERROR", "No command specified. Use 'help' to see usage.");
            System.exit(1);
        }

        String command = args[0];
        try {
            // frism license path system property
            System.setProperty("frism.license.path", "./license");

            if ("help".equalsIgnoreCase(command)) {
                printHelp();
            } else if ("connect".equalsIgnoreCase(command)) {
                handleConnect(args);
            } else if ("get-cm".equalsIgnoreCase(command)) {
                handleGetCm(args);
            } else if ("get-repo-id".equalsIgnoreCase(command)) {
                handleGetRepoId(args);
            } else if ("check-in".equalsIgnoreCase(command)) {
                handleCheckIn(args);
            } else if ("check-out".equalsIgnoreCase(command)) {
                handleCheckOut(args);
            } else if ("get-file-id".equalsIgnoreCase(command)) {
                handleGetFileId(args);
            } else if ("check-out-cancel".equalsIgnoreCase(command)) {
                handleCheckOutCancel(args);
            } else if ("get-versions".equalsIgnoreCase(command)) {
                handleGetVersions(args);
            } else if ("download-resource".equalsIgnoreCase(command)) {
                handleDownloadResource(args);
            } else if ("deploy-stage".equalsIgnoreCase(command)) {
                handleDeployStage(args);
            } else if ("deploy-real".equalsIgnoreCase(command)) {
                handleDeployReal(args);
            } else if ("get-cm-list".equalsIgnoreCase(command)) {
                handleGetCmList(args);
            } else if ("get-checkout-user".equalsIgnoreCase(command)) {
                handleGetCheckoutUser(args);
            } else {
                printError("UNKNOWN_COMMAND", "Unknown command: " + command);
                System.exit(1);
            }
        } catch (BizException e) {
            printError(e.getCode(), e.getMessage(), e.getDetailMessage());
            System.exit(2);
        } catch (Exception e) {
            printError("SYSTEM_ERROR", e.getMessage());
            e.printStackTrace();
            System.exit(3);
        }
    }

    private static void printHelp() {
        System.out.println("Frism Configuration Management (CM) CLI Tool");
        System.out.println("Usage: java com.kbcard.cm.cli.CmCli <command> [options]");
        System.out.println("Commands:");
        System.out.println("  connect --userId <userId>");
        System.out.println("  get-cm --userId <userId> --cmId <cmId>");
        System.out.println("  get-repo-id --userId <userId> --repoName <repoName>");
        System.out.println("  check-in --userId <userId> --cmId <cmId> --repoName <repoName> --filePath <filePath> --fileName <fileName> [--isNew <true|false>] [--isCrc <true|false>] [--desc <desc>]");
        System.out.println("  check-out --userId <userId> --repoName <repoName> --filePath <filePath> --fileName <fileName> [--isOverride <true|false>]");
        System.out.println("  get-file-id --userId <userId> --repoName <repoName> --filePath <filePath> --fileName <fileName>");
        System.out.println("  check-out-cancel --userId <userId> --repoName <repoName> --filePath <filePath> --fileName <fileName>");
        System.out.println("  get-versions --userId <userId> --repoName <repoName> --filePath <filePath> --fileName <fileName>");
        System.out.println("  download-resource --userId <userId> --repoName <repoName> --filePath <filePath> --fileName <fileName> --version <version> --downloadPath <downloadPath>");
        System.out.println("  deploy-stage --userId <userId> --cmId <cmId>");
        System.out.println("  deploy-real --userId <userId> --cmId <cmId> [--deployTime <deployTime>]");
        System.out.println("  get-cm-list --userId <userId> [--cmPackageName <cmPackageName>]");
        System.out.println("  get-checkout-user --userId <userId> --repoName <repoName> --filePath <filePath> --fileName <fileName>");
    }

    private static HashMap<String, String> parseArgs(String[] args) {
        HashMap<String, String> map = new HashMap<String, String>();
        for (int i = 1; i < args.length; i++) {
            if (args[i].startsWith("--") && i + 1 < args.length) {
                String key = args[i].substring(2);
                String val = args[i+1];
                map.put(key, val);
                i++;
            }
        }
        return map;
    }

    private static void handleConnect(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        if (userId == null) {
            printError("PARAM_ERROR", "Missing --userId parameter.");
            System.exit(1);
        }
        UtilCmData cmData = UtilCm.connect(userId);
        System.out.println("{\"success\":true,\"userId\":\"" + escapeJson(userId) + "\"}");
        UtilCm.disconnect(cmData);
    }

    private static void handleGetCm(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String cmId = params.get("cmId");
        if (userId == null) {
            printError("PARAM_ERROR", "Missing --userId parameter.");
            System.exit(1);
        }
        UtilCmData cmData = UtilCm.connect(userId);
        cmData = UtilCm.getCm(cmData, cmId, userId);
        String finalCmId = cmData.getCm().getCmId();
        String title = cmData.getCm().getTitle();
        String status = cmData.getCm().getStatus();
        String cmStatus = cmData.getCm().getCmStatus();
        String cmTestStatus = cmData.getCm().getCmTestStatus();
        System.out.println("{"
            + "\"success\":true,"
            + "\"userId\":\"" + escapeJson(userId) + "\","
            + "\"cmId\":\"" + escapeJson(finalCmId) + "\","
            + "\"title\":\"" + escapeJson(title) + "\","
            + "\"status\":\"" + escapeJson(status) + "\","
            + "\"cmStatus\":\"" + escapeJson(cmStatus) + "\","
            + "\"cmTestStatus\":\"" + escapeJson(cmTestStatus) + "\""
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static void handleGetRepoId(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String repoName = params.get("repoName");
        if (userId == null || repoName == null) {
            printError("PARAM_ERROR", "Missing --userId or --repoName parameter.");
            System.exit(1);
        }
        UtilCmData cmData = UtilCm.connect(userId);
        int repoId = UtilCm.getRepositoryId(cmData, repoName);
        System.out.println("{"
            + "\"success\":true,"
            + "\"repoName\":\"" + escapeJson(repoName) + "\","
            + "\"repoId\":" + repoId
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static void handleCheckIn(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String cmId = params.get("cmId");
        String repoName = params.get("repoName");
        String filePath = params.get("filePath");
        String fileName = params.get("fileName");
        boolean isNew = "true".equalsIgnoreCase(params.get("isNew"));
        boolean isCrc = "true".equalsIgnoreCase(params.get("isCrc"));
        String desc = params.get("desc");
        if (desc == null) desc = "kobi system modification";

        if (userId == null || repoName == null || filePath == null || fileName == null) {
            printError("PARAM_ERROR", "Missing required parameters for check-in.");
            System.exit(1);
        }

        UtilCmData cmData = UtilCm.connect(userId);
        cmData = UtilCm.getCm(cmData, cmId, userId);
        int repoId = UtilCm.getRepositoryId(cmData, repoName);
        UtilCm.checkIn(cmData, repoId, filePath, fileName, isCrc, isNew, userId, desc);
        System.out.println("{"
            + "\"success\":true,"
            + "\"cmId\":\"" + escapeJson(cmData.getCm().getCmId()) + "\","
            + "\"repoName\":\"" + escapeJson(repoName) + "\","
            + "\"repoId\":" + repoId + ","
            + "\"filePath\":\"" + escapeJson(filePath) + "\","
            + "\"fileName\":\"" + escapeJson(fileName) + "\""
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static void handleCheckOut(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String repoName = params.get("repoName");
        String filePath = params.get("filePath");
        String fileName = params.get("fileName");
        boolean isOverride = "true".equalsIgnoreCase(params.get("isOverride"));

        if (userId == null || repoName == null || filePath == null || fileName == null) {
            printError("PARAM_ERROR", "Missing required parameters for check-out.");
            System.exit(1);
        }

        UtilCmData cmData = UtilCm.connect(userId);
        int repoId = UtilCm.getRepositoryId(cmData, repoName);
        UtilCm.checkOut(cmData, repoId, filePath, fileName, isOverride, userId);
        System.out.println("{"
            + "\"success\":true,"
            + "\"repoName\":\"" + escapeJson(repoName) + "\","
            + "\"repoId\":" + repoId + ","
            + "\"filePath\":\"" + escapeJson(filePath) + "\","
            + "\"fileName\":\"" + escapeJson(fileName) + "\""
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static void handleGetFileId(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String repoName = params.get("repoName");
        String filePath = params.get("filePath");
        String fileName = params.get("fileName");

        if (userId == null || repoName == null || filePath == null || fileName == null) {
            printError("PARAM_ERROR", "Missing required parameters for get-file-id.");
            System.exit(1);
        }

        UtilCmData cmData = UtilCm.connect(userId);
        int repoId = UtilCm.getRepositoryId(cmData, repoName);
        int fileId = UtilCm.getFileId2(cmData, repoId, filePath, fileName);
        System.out.println("{"
            + "\"success\":true,"
            + "\"repoName\":\"" + escapeJson(repoName) + "\","
            + "\"repoId\":" + repoId + ","
            + "\"filePath\":\"" + escapeJson(filePath) + "\","
            + "\"fileName\":\"" + escapeJson(fileName) + "\","
            + "\"fileId\":" + fileId
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static void handleCheckOutCancel(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String repoName = params.get("repoName");
        String filePath = params.get("filePath");
        String fileName = params.get("fileName");

        if (userId == null || repoName == null || filePath == null || fileName == null) {
            printError("PARAM_ERROR", "Missing required parameters for check-out-cancel.");
            System.exit(1);
        }

        UtilCmData cmData = UtilCm.connect(userId);
        int repoId = UtilCm.getRepositoryId(cmData, repoName);
        UtilCm.checkOutCancel(cmData, repoId, filePath, fileName, userId);
        System.out.println("{"
            + "\"success\":true,"
            + "\"repoName\":\"" + escapeJson(repoName) + "\","
            + "\"repoId\":" + repoId + ","
            + "\"filePath\":\"" + escapeJson(filePath) + "\","
            + "\"fileName\":\"" + escapeJson(fileName) + "\""
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static void handleGetVersions(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String repoName = params.get("repoName");
        String filePath = params.get("filePath");
        String fileName = params.get("fileName");

        if (userId == null || repoName == null || filePath == null || fileName == null) {
            printError("PARAM_ERROR", "Missing required parameters for get-versions.");
            System.exit(1);
        }

        UtilCmData cmData = UtilCm.connect(userId);
        int repoId = UtilCm.getRepositoryId(cmData, repoName);
        int fileId = UtilCm.getFileId2(cmData, repoId, filePath, fileName);
        ArrayList<HashMap<String, String>> versions = UtilCm.getVersionListByResId(cmData, repoId, fileId);
        System.out.println("{"
            + "\"success\":true,"
            + "\"repoName\":\"" + escapeJson(repoName) + "\","
            + "\"repoId\":" + repoId + ","
            + "\"filePath\":\"" + escapeJson(filePath) + "\","
            + "\"fileName\":\"" + escapeJson(fileName) + "\","
            + "\"fileId\":" + fileId + ","
            + "\"versions\":" + listToJson(versions)
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static void handleDownloadResource(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String repoName = params.get("repoName");
        String filePath = params.get("filePath");
        String fileName = params.get("fileName");
        String version = params.get("version");
        String downloadPath = params.get("downloadPath");

        if (userId == null || repoName == null || filePath == null || fileName == null || version == null || downloadPath == null) {
            printError("PARAM_ERROR", "Missing required parameters for download-resource.");
            System.exit(1);
        }

        UtilCmData cmData = UtilCm.connect(userId);
        int repoId = UtilCm.getRepositoryId(cmData, repoName);
        int fileId = UtilCm.getFileId2(cmData, repoId, filePath, fileName);
        UtilCm.getDownloadResource(cmData, fileId, version, downloadPath);
        System.out.println("{"
            + "\"success\":true,"
            + "\"repoName\":\"" + escapeJson(repoName) + "\","
            + "\"repoId\":" + repoId + ","
            + "\"filePath\":\"" + escapeJson(filePath) + "\","
            + "\"fileName\":\"" + escapeJson(fileName) + "\","
            + "\"fileId\":" + fileId + ","
            + "\"version\":\"" + escapeJson(version) + "\","
            + "\"downloadPath\":\"" + escapeJson(downloadPath) + "\""
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static void handleDeployStage(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String cmId = params.get("cmId");
        if (userId == null || cmId == null) {
            printError("PARAM_ERROR", "Missing --userId or --cmId parameter.");
            System.exit(1);
        }
        UtilCmData cmData = UtilCm.connect(userId);
        cmData = UtilCm.getCm(cmData, cmId, userId);
        UtilCm.deployStage(cmData);
        System.out.println("{"
            + "\"success\":true,"
            + "\"userId\":\"" + escapeJson(userId) + "\","
            + "\"cmId\":\"" + escapeJson(cmId) + "\","
            + "\"environment\":\"stage\""
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static void handleDeployReal(String[] args) throws BizException {
        printError("SECURITY_BLOCK", "Deploy to real (production) environment is blocked by security policy.", "\uc0ac\ub0b4 \ubcf4\uc548 \ubc0f \uc6b4\uc601 \uc815\ud569\uc131 \uc815\ucc45\uc5d0 \uc758\ud574 AI Assistant\ub97c \ud1b5\ud55c \uc6b4\uc601 \ud658\uacbd \ubc30\ud3ec(deploy-real) \uc2e4\ud589\uc740 \uc804\uba74 \uae08\uc9c0\ub418\uc5b4 \uc788\uc2b5\ub2c8\ub2e4.");
        System.exit(4);
    }

    private static void handleGetCmList(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String cmPackageName = params.get("cmPackageName");
        if (userId == null) {
            printError("PARAM_ERROR", "Missing --userId parameter.");
            System.exit(1);
        }
        UtilCmData cmData = UtilCm.connect(userId);
        ArrayList<HashMap<String, String>> cmList = UtilCm.getCMList(cmData, cmPackageName, userId);
        System.out.println("{"
            + "\"success\":true,"
            + "\"userId\":\"" + escapeJson(userId) + "\","
            + "\"cmList\":" + listToJson(cmList)
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static void handleGetCheckoutUser(String[] args) throws BizException {
        HashMap<String, String> params = parseArgs(args);
        String userId = params.get("userId");
        String repoName = params.get("repoName");
        String filePath = params.get("filePath");
        String fileName = params.get("fileName");

        if (userId == null || repoName == null || filePath == null || fileName == null) {
            printError("PARAM_ERROR", "Missing required parameters for get-checkout-user.");
            System.exit(1);
        }

        UtilCmData cmData = UtilCm.connect(userId);
        int repoId = UtilCm.getRepositoryId(cmData, repoName);
        int fileId = UtilCm.getFileId2(cmData, repoId, filePath, fileName);
        String checkoutUser = UtilCm.getCheckoutUserId(cmData, fileId);
        System.out.println("{"
            + "\"success\":true,"
            + "\"repoName\":\"" + escapeJson(repoName) + "\","
            + "\"repoId\":" + repoId + ","
            + "\"filePath\":\"" + escapeJson(filePath) + "\","
            + "\"fileName\":\"" + escapeJson(fileName) + "\","
            + "\"fileId\":" + fileId + ","
            + "\"checkoutUserId\":" + (checkoutUser != null ? "\"" + escapeJson(checkoutUser) + "\"" : "null")
            + "}");
        UtilCm.disconnect(cmData);
    }

    private static String escapeJson(String str) {
        if (str == null) return "null";
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < str.length(); i++) {
            char ch = str.charAt(i);
            switch (ch) {
                case '"': sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\b': sb.append("\\b"); break;
                case '\f': sb.append("\\f"); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                default:
                    if (ch < ' ') {
                        String t = "000" + Integer.toHexString(ch);
                        sb.append("\\u" + t.substring(t.length() - 4));
                    } else {
                        sb.append(ch);
                    }
            }
        }
        return sb.toString();
    }

    private static String mapToJson(HashMap<String, String> map) {
        if (map == null) return "null";
        StringBuilder sb = new StringBuilder();
        sb.append("{");
        boolean first = true;
        for (String key : map.keySet()) {
            if (!first) sb.append(",");
            sb.append("\"").append(escapeJson(key)).append("\":");
            String val = map.get(key);
            if (val == null) {
                sb.append("null");
            } else {
                sb.append("\"").append(escapeJson(val)).append("\"");
            }
            first = false;
        }
        sb.append("}");
        return sb.toString();
    }

    private static String listToJson(ArrayList<HashMap<String, String>> list) {
        if (list == null) return "null";
        StringBuilder sb = new StringBuilder();
        sb.append("[");
        boolean first = true;
        for (HashMap<String, String> map : list) {
            if (!first) sb.append(",");
            sb.append(mapToJson(map));
            first = false;
        }
        sb.append("]");
        return sb.toString();
    }

    private static void printError(String code, String message) {
        printError(code, message, null);
    }

    private static void printError(String code, String message, String detail) {
        System.out.println("{"
            + "\"success\":false,"
            + "\"errorCode\":\"" + escapeJson(code) + "\","
            + "\"errorMessage\":\"" + escapeJson(message) + "\","
            + "\"errorDetail\":" + (detail != null ? "\"" + escapeJson(detail) + "\"" : "null")
            + "}");
    }
}
