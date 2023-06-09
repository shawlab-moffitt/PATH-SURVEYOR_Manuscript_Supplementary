


####----Install and load packages----####

packages <- c("shiny","shinythemes","shinyjqui","shinycssloaders","dplyr","DT","readr","ggplot2")

installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
  install.packages(packages[!installed_packages])
}
invisible(lapply(packages, library, character.only = TRUE))
#bioconductor packages
bioCpacks <- c("clusterProfiler","enrichplot")
installed_packages_BIOC <- bioCpacks %in% rownames(installed.packages())
if (any(installed_packages_BIOC == FALSE)) {
  BiocManager::install(bioCpacks[!installed_packages_BIOC], ask = F)
}
invisible(lapply(bioCpacks, library, character.only = TRUE))


####----File Input----####

GeneSet_File <- "GeneSets_symNcat_v5.zip"

PreSet_CoxH_Ranked_Genes_file <- "ICI_iAtlas_Skin_Pre_OS_Genes_coxh_ranked_Inverse.txt"


####----Read In and Sort File----####

GeneSet <- as.data.frame(read_delim(GeneSet_File, delim = '\t', col_names = T))


PreSet_CoxH_Ranked_Genes <- as.data.frame(read_delim(PreSet_CoxH_Ranked_Genes_file, delim = '\t', col_names = T, comment = "#"))


#increase file upload size
options(shiny.maxRequestSize=50*1024^2)

load_data <- function() {
  Sys.sleep(2)
  hide("loading_page")
  show("main_content")
}

server <- function(input, output, session) {
  
  load_data()
  
  ####----Render UI----####
    
  output$rendSpecimenType <- renderUI({
    
    if (input$UserUploadCheck == FALSE) {
      
      radioButtons("SpecimenType","Choose Specimen Type:", choices = c("Human","Mouse"), inline = T)
      
    }
    
  })
  
  
  output$rendGeneSetChosen <- renderUI({
    
    data_options <- unique(GeneSet[,3])
    data_options_HS <- grep("_mm",data_options,value = T, invert = T)
    
    if (input$UserUploadCheck == FALSE) {
      if (!is.null(input$SpecimenType)) {
        if (input$SpecimenType == "Human") {
          selectInput("GeneSetChosen","Choose Gene Set:",
                      choices = c("MSigDB - Hallmark",data_options_HS),
                      selected = "MSigDB - Hallmark")
        }
        else if (input$SpecimenType == "Mouse") {
          selectInput("GeneSetChosen","Choose Gene Set:",
                      choices = c("MSigDB - Hallmark" = "Hallmark_mm","MSigDB" = "msigdb_mm","Cell Marker" = "cellm_mm"),
                      selected = "MSigDB - Hallmark")
        }
      }
    }
    
  })
  
  output$rendEnrichTable <- renderUI({
    
    #req(input$UserGeneList)
    withSpinner(DT::dataTableOutput("EnrichTable", width = "100%"), type = 6)
    
  })
  
  output$renddnldEnrichTable <- renderUI({
    
    #req(input$UserGeneList)
    downloadButton("dnldEnrichTable","Download Enriched Signatures Table")
    
  })
  
  output$rendUserGSupload <- renderUI({
    
    if (is.null(input$GeneSetChosen) == FALSE) {
      
      if (input$UserUploadCheck == TRUE) {
        
        fileInput("UserGeneSet","Upload Gene Set File")
        
      }
      
    }
    
  })
  
  output$rendUserGSheaderCheck <- renderUI({
    
    if (is.null(input$GeneSetChosen) == FALSE) {
      
      if (input$UserUploadCheck == TRUE) {
        
        checkboxInput("UserGSheaderCheck","Header",value = T)
        
      }
      
    }
    
  })
  
  ####----Reactives----####
  
  ## User Upload gene set reactive
  user_gs <- reactive({
    
    header_check <- input$UserGSheaderCheck
    gs.u <- input$UserGeneSet
    ext <- tools::file_ext(gs.u$datapath)
    req(gs.u)
    validate(need(ext == c("gmt","tsv","txt"), "Please upload .gmt, .tsv, or .txt file"))
    
    # If user provides GMT file
    if (ext == "gmt") {
      gmt <- read.gmt(gs.u$datapath)
      colnames(gmt) <- c("term","gene")
      gs_u <- gmt
    }
    
    # If user provides tab-delim file
    else if (ext == "txt" | ext == "tsv") {
      
      gmt <- as.data.frame(read_delim(gs.u$datapath, delim = '\t', col_names = header_check))
      
      if (ncol(gmt) == 1) {
        paths <- as.vector(gmt[,1])
        paths <- gsub("[[:punct:]]",".",paths)
        gs_u <- GeneSet[which(GeneSet$term %in% paths),]
      }
      else if (ncol(gmt) == 2) {
        colnames(gmt) <- c("term","gene")
        gs_u <- gmt
      }
      else if (ncol(gmt) > 2) {
        paths <- as.vector(gmt[,1])
        paths <- gsub("[[:punct:]]",".",paths)
        gs_u <- GeneSet[which(GeneSet$term %in% paths),]
      }
      
    }
    
    gs_u
    
  })
  
  #gmt reactive based on user choice for GSEA
  gmt_react <- reactive({
    
    if (input$UserUploadCheck == TRUE) {
      
      #req(input$UserGeneList)
      gmt <- user_gs()
      
    }
    else {
      
      gs_chosen <- input$GeneSetChosen
      
      if (gs_chosen == "MSigDB - Hallmark") {
        
        msigdb_sub <- GeneSet[which(GeneSet[,3] == "MSigDB"),]
        GeneSet_sub <- msigdb_sub[which(grepl("HALLMARK",msigdb_sub$term)),]
        gmt <- GeneSet_sub[,c(1,2)]
        
      }
      else if (gs_chosen == "Hallmark_mm") {
        
        msigdb_sub <- GeneSet[which(GeneSet[,3] == "msigdb_mm"),]
        GeneSet_sub <- msigdb_sub[which(grepl("HALLMARK",msigdb_sub$term)),]
        gmt <- GeneSet_sub[,c(1,2)]
        
      }
      else {
        
        GeneSet_sub <- GeneSet[which(GeneSet[,3] == gs_chosen),]
        gmt <- GeneSet_sub[,c(1,2)]
        
      }

    }
    
  })
  
  output$rendGeneSetPreview <- renderUI({
    
    if (input$PreviewGeneSet == TRUE) {
      
      div(DT::dataTableOutput("GeneSetPreview"), style = "font-size:10px; height:450px; overflow-X: scroll")
      
    }
    
  })
  
  output$GeneSetPreview <- DT::renderDataTable({
    
    gmt <- gmt_react()
    geneset_names <- data.frame("Gene_Set_Name" = unique(gmt[,1]))
    DT::datatable(geneset_names,
                  options = list(keys = TRUE,
                                 searchHighlight = TRUE,
                                 pageLength = 10,
                                 lengthMenu = c("10", "20", "50", "100")),
                  rownames = F)
    
    
  })
  
  #generate ranked list of genes
  user_gl_df <- reactive({
    
    #print(input$UserGeneList)
    if (is.null(input$UserGeneList)) {
      df <- PreSet_CoxH_Ranked_Genes
      df
    } else {
      header_check <- input$UserGeneListheaderCheck
      gs.u <- input$UserGeneList
      ext <- tools::file_ext(gs.u$datapath)
      req(gs.u)
      validate(need(ext == c("tsv","txt"), "Please upload .tsv or .txt file"))
      
      df <- as.data.frame(read_delim(gs.u$datapath, delim = '\t', col_names = header_check, comment = "#"))
      df
    }
    
  })
  
  #generate ranked list of genes
  user_gl <- reactive({
    
    df <- user_gl_df()
    
    # assume just list of gene symbols
    if (ncol(df) == 1) {
      
      # generate rank from high to low
      ranking <- seq(from = nrow(df),to = 1)
      names(ranking) <- as.character(df[,1])
      
    }
    # assume gene symbols and rank
    else if (ncol(df) == 2) {
      
      ranking <- df[,2]
      names(ranking) <- as.character(df[,1])
      ranking <- sort(ranking, decreasing = T)
      
    }
    # assume gene symbols and general annotation columns
    else if (ncol(df) > 2) {
      
      # assume Coxh Ranking table is output
      if (colnames(df)[2] == "Hazard_Ratio" | colnames(df)[2] == "estimate") {
        
        ranking <- df[,2]
        names(ranking) <- as.character(df[,1])
        ranking <- sort(ranking, decreasing = T)
        
      }
      else {
        
        # generate rank from high to low
        ranking <- seq(from = nrow(df),to = 1)
        names(ranking) <- as.character(df[,1])
        
      }
      
    }
    
    ranking
    
  })
  
  EnrichTabReact <- reactive({
    
    set.seed(input$UserSeedSet)
    gmt <- gmt_react()
    ranked_genes <- user_gl()
    pval <- input$gseaPval
    gsea.res <- GSEA(ranked_genes,
                     TERM2GENE = gmt,
                     eps = NA, pvalueCutoff = pval,
                     minGSSize = 5, maxGSSize = 10000,
                     nPermSimple = 5000,
                     seed = T)
    gsea.res
    
  })
  
  
  LeadingEdgeReact <- reactive({
    
    res <- EnrichTabReact()
    res_df <- res@result
    geneset_name <- as.character(res_df[input$GeneSetTable_rows_selected,1])
    NES = res_df$NES[which(res_df[,'ID']==geneset_name)]
    geneList <- user_gl()
    ## Subset core enriched genes
    genes1 <- as.matrix(res_df[which(res_df$ID==geneset_name),"core_enrichment"])
    genes2 <- strsplit(genes1,"/")
    if (length(genes2) > 0) {
      GeneSymbol <- as.data.frame(genes2)
      colnames(GeneSymbol)[1] <- "Gene_Symbol"
      GeneSymbol$Leading_Edge_Rank <- as.numeric(rownames(GeneSymbol))
      GeneSymbol <- GeneSymbol[,c("Leading_Edge_Rank","Gene_Symbol")]
      
      ranking_df <- stack(geneList)
      uploaded_df <- user_gl_df()
      if (input$UserGeneListheaderCheck == TRUE) {
        if (ncol(uploaded_df) == 2) {
          rank_col_name <- colnames(uploaded_df)[2]
        }
        if (ncol(uploaded_df) == 1) {
          rank_col_name <- "Overall_Rank"
        }
        if (ncol(uploaded_df) > 2) {
          if (colnames(uploaded_df)[2] == "Hazard_Ratio" | colnames(uploaded_df)[2] == "estimate") {
            rank_col_name <- "Hazard_Ratio"
          }
          else {
            rank_col_name <- "Overall_Rank"
          }
        }
      }
      if (input$UserGeneListheaderCheck == FALSE) {
        if (ncol(uploaded_df) == 2) {
          rank_col_name <- "User_Uploaded_Ranking"
        }
        if (ncol(uploaded_df) != 2) {
          rank_col_name <- "Overall_Rank"
        }
      }
      
      colnames(ranking_df) <- c(rank_col_name,"Gene_Symbol")
      
      Leading_Merge <- merge(GeneSymbol,ranking_df,by = "Gene_Symbol",all.x = T)
      if (NES < 0) {
        Leading_Merge <- Leading_Merge[order(Leading_Merge[,1]),]
      }
      else if (NES > 0) {
        Leading_Merge <- Leading_Merge[order(Leading_Merge[,1], decreasing = F),]
      }
      Leading_Merge <- Leading_Merge[,c("Leading_Edge_Rank","Gene_Symbol",rank_col_name)]
      Leading_Merge
    }
    
  })
  
  ####----Data Tables----####
  
  output$EnrichTable <- DT::renderDataTable({
    
    res <- EnrichTabReact()
    res_df <- res@result
    
    if (nrow(res@result) == 0) {
      
      res_df <- data.frame("No_term_enriched_under_specific_Pvalue_Cutoff")
      
    }
    
    DT::datatable(res_df,
                  extensions = c("KeyTable", "FixedHeader","FixedColumns"),
                  options = list(keys = T,
                                 searchHighlight = T,
                                 pageLength = 20,
                                 lengthMenu = c("10", "25", "50", "100"),
                                 scrollX = T,
                                 autoWidth = TRUE,
                                 fixedColumns = list(leftColumns = 1)),
                  rownames = F) %>%
      formatRound(columns = c(2:10), digits = 4)
    
  })
  
  output$GeneSetTable <- DT::renderDataTable({
    
    res <- EnrichTabReact()
    res_df <- res@result
    GeneSets <- res_df[,c(1,5,6)]
    
    DT::datatable(GeneSets,
                  selection = list(mode = 'single', selected = 1),
                  options = list(keys = TRUE,
                                 searchHighlight = TRUE,
                                 pageLength = 20,
                                 lengthMenu = c("10", "20", "50", "100")),
                  rownames = F) %>%
      formatRound(columns = c(2,3), digits = 4)
    
  })
  
  output$LeadingEdgeGenes <- DT::renderDataTable({
    
    LEGs <- LeadingEdgeReact()
    DT::datatable(LEGs,
                  options = list(paging = F,
                                 autoWidth = TRUE,
                                 columnDefs = list(list(className = 'dt-center', targets = 0:2))),
                  rownames = F)
    
  })
  
  ####----Enrichment Plot----####
  
  output$enrichplot <- renderPlot({
    
    if (length(input$GeneSetTable_rows_selected) > 0) {
      
      res <- EnrichTabReact()
      res_df <- res@result
      geneset_name <- as.character(res_df[input$GeneSetTable_rows_selected,1])
      gseaplot2(res,
                geneset_name,
                geneset_name,
                pvalue_table = F)
      
    }
    
  })
  
  output$NESandPval <- renderText({
    
    if (length(input$GeneSetTable_rows_selected) > 0){
      res <- EnrichTabReact()
      gsea.df <- as.data.frame(res@result)
      GS = as.character(gsea.df[input$GeneSetTable_rows_selected,1])
      NES = gsea.df$NES[which(gsea.df[,'ID']==GS)]
      Pval = gsea.df$pvalue[which(gsea.df[,'ID']==GS)]
      NES.o <- paste0("NES: ", NES)
      Pval.o <- paste0("Pvalue: ", Pval)
      paste(NES.o, Pval.o, sep = '\n')
    }
    else if (length(input$msigdbTable_rows_selected) == 0){
      paste("Please select gene set from side panel table to begin.", sep = '')
    }
    
  })
  
  ####----Downloads----####
  
  output$dnldEnrichTable <- downloadHandler(
    filename = function() {
      paste("EnrichedSignaturesTable.txt",sep = "")
    },
    content = function(file) {
      res <- EnrichTabReact()
      res_df <- res@result
      write_delim(res_df,file,delim = '\t')
    }
  )
  
  output$dnldPlotSVG_gsea <- downloadHandler(
    filename = function() {
      
      res <- EnrichTabReact()
      gsea.df <- as.data.frame(res@result)
      GS = as.character(gsea.df[input$GeneSetTable_rows_selected,1])
      paste(GS,"_EnrichmentPlot.svg",sep = "")
      
    },
    content = function(file) {
      
      res <- EnrichTabReact()
      res_df <- res@result
      geneset_name <- as.character(res_df[input$GeneSetTable_rows_selected,1])
      p <- gseaplot2(res,
                geneset_name,
                geneset_name,
                pvalue_table = F)
      ggsave(file,p, width = 10, height = 8)
      
    }
  )
  output$dnldPlotPDF_gsea <- downloadHandler(
    filename = function() {
      
      res <- EnrichTabReact()
      gsea.df <- as.data.frame(res@result)
      GS = as.character(gsea.df[input$GeneSetTable_rows_selected,1])
      paste(GS,"_EnrichmentPlot.pdf",sep = "")
      
    },
    content = function(file) {
      
      res <- EnrichTabReact()
      res_df <- res@result
      geneset_name <- as.character(res_df[input$GeneSetTable_rows_selected,1])
      p <- gseaplot2(res,
                     geneset_name,
                     geneset_name,
                     pvalue_table = F)
      ggsave(file,p, width = 10, height = 8)
      
    }
  )
  
  output$LEGdownload <- downloadHandler(
    
    filename = function() {
      
      res <- EnrichTabReact()
      res_df <- res@result
      geneset_name <- as.character(res_df[input$GeneSetTable_rows_selected,1])
      paste(geneset_name,"_LeadingEdgeGenes.txt",sep ="")
      
    },
    content = function(file) {
      
      LEGs <- LeadingEdgeReact()
      write_delim(LEGs,file,delim = '\t')
      
    }
    
  )
  
}
















