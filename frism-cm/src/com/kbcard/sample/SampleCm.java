package com.kbcard.sample;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;

import com.kbcard.cm.util.UtilCm;
import com.kbcard.cm.util.UtilCmData;
import com.kbcard.excption.BizException;
import com.kbcard.frism.object.CmPackage;

public class SampleCm 
{
	public static void main(String[] args) {
		try
		{
			new SampleCm().execute();
		}
		catch (Exception e)
		{
			e.printStackTrace();
		}
	}

	public void execute() throws Exception
	{
		String bizCode  = "UBW"; // CM 업무코드
		String cmDesc   = "devon framework 자원"; // 자원 반입시 설명
		String userId   = "MT00201"; // frism user id (직원번호)
		String repoName = "UBW_WEB"; // 레파지토리
		String cmId 	= "UBW260407"; // CM ID (null 일 경우 생성)
		int    repoId    = 0;
		String filePath  = "/src/com/kbcard/ext/common/";
		String fileName  = "ClassWatchServlet.java"; 
		
		UtilCmData  cmData    = null;
		try
		{
			// frism 라이센스 파일 위치
			System.setProperty("frism.license.path", 	"./license");
			System.setProperty("frism.cm.biz.code", 	bizCode);
			System.setProperty("frism.cm.desc", 		cmDesc);
			
			cmData = UtilCm.connect(userId);
			System.out.println("[CMTEST] connect, cmData="+cmData);
			repoId = UtilCm.getRepositoryId(cmData, repoName);
			System.out.println("[CMTEST] repoId="+repoId);
			cmData = UtilCm.getCm(cmData, cmId, userId);
			System.out.println("[CMTEST] getCm, cm id="+cmData.getCm().getCmId());
			
			int fileId = UtilCm.getFileId2(cmData, repoId, filePath, fileName);
			System.out.println("[CMTEST] fileId="+fileId);
			/*
		    UtilCm.checkIn(cmData, repoId, filePath, fileName, false, true, userId);
		    System.out.println("[CMTEST] checkIn");
		    
		    UtilCm.addResource(cmData, repoId, filePath, filePath+fileName, userId);
		    System.out.println("[CMTEST] addResource");
		    
		    UtilCm.deployStage(cmData);
		    System.out.println("[CMTEST] deployStage");
		    */
		}
		catch (BizException e)
		{
			e.printStackTrace();
			System.out.println("[CMTEST] 형상 배포중 오류발생~, custmsg="+e.getDetailMessage());
		}
		catch (Exception e)
		{
			e.printStackTrace();
			System.out.println("[CMTEST] 형상 배포중 기타오류발생~"+e);
		}
		finally
		{
			if (cmData != null)
				UtilCm.disconnect(cmData);
		}
	}
}
