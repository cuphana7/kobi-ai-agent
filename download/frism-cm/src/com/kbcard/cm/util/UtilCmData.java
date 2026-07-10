package com.kbcard.cm.util;

import java.util.ArrayList;
import java.util.HashMap;

import com.kbcard.frism.manager.KbCardCmManager;
import com.kbcard.frism.object.CmPackage;
import com.kbcard.frism.object.CmResource;

public class UtilCmData
{
    public static String CM패키지명       = "CM패키지명";   // 패키지명
    public static String CMID             = "CMID";         // CM ID
     
    public static String 파일사이즈       = "파일사이즈";   // 파일사이즈
    public static String 파일수정일       = "파일수정일";   // 파일수정일
    public static String 파일명           = "파일명";       // 파일명
    public static String 파일ID           = "파일ID";       // 파일ID
    public static String 파일수정자       = "파일수정자";   // 파일수정자
    public static String 파일버전         = "파일버전";     // 파일버전
    public static String 파일변경사유     = "파일변경사유"; // 파일변경사유
    public static String 파일리얼반영     = "파일리얼반영"; // 파일리얼반영
    
    private KbCardCmManager         cmManager;
    private CmPackage               cm;
    
    private ArrayList<HashMap<String, String>> cmPackage;
    private ArrayList<HashMap<String, String>> cmResourceVersion;
    
    public UtilCmData()
    {
        cmPackage           = new ArrayList<HashMap<String, String>>();
        cmResourceVersion   = new ArrayList<HashMap<String, String>>();
    }
    
    // CM 리소스 버전 초기화
    public void clearCmResourceVersion()
    {
    	cmResourceVersion.clear();
    }
    
    /**
     * CM 관리자 입력
     * @param cmManager
     */
    public void setCmManager(KbCardCmManager cmManager)
    {
        this.cmManager = cmManager;
    }
    
    /**
     * CM 관리자 반환
     * @return
     */
    public KbCardCmManager getCmManager()
    {
        return cmManager;
    }
    
    /**
     * CM 객체 입력
     * @param cm
     */
    public void setCm(CmPackage cm)
    {
        this.cm = cm;
    }
    
    /**
     * CM 객체 반환
     * @return
     */
    public CmPackage getCm()
    {
        return cm;
    }
    
    /**
     * CM 패키지 리스트 입력
     * @param cmpak
     */
    public void setCmPackage(CmPackage cmpak)
    {
        HashMap<String, String> packageMap = new HashMap<String, String>();
        
        String packageName  = cmpak.getTitle();
        String cmId         = cmpak.getCmId();
        
        packageMap.put(CM패키지명,    packageName);
        packageMap.put(CMID,          cmId);
        
        cmPackage.add(packageMap);
    }

    /**
     * CM 패키지 리스트 반환
     * @return
     */
    public ArrayList<HashMap<String, String>> getCmPackage()
    {
        return cmPackage;
    }
    
    /**
     * 자원정보 입력
     * @param resource
     */
    public void setResourceVersion(CmResource resource)
    {
        HashMap<String, String> versionMap = new HashMap<String, String>();
        
        long    fileSize  = resource.getFileSize();
        String  fileDate  = resource.getFileDate();
        
        versionMap.put(파일사이즈,    ""+fileSize);
        versionMap.put(파일수정일,    fileDate);
        versionMap.put(파일명,        resource.getFileName());
        versionMap.put(파일ID,        ""+resource.getFileId());
        versionMap.put(파일수정자,    resource.getUserName());
        versionMap.put(파일버전,      resource.getVersion());
        versionMap.put(파일변경사유,  resource.getDesc());
        versionMap.put(파일리얼반영,  resource.getIsProd());
        
        cmResourceVersion.add(versionMap);
    }
    
    /**
     * 자원 정보 리스트 반환
     * @return
     */
    public ArrayList<HashMap<String, String>> getResourceVersion()
    {
        return cmResourceVersion;
    }
}
