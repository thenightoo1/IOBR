






#' Searching for mutations related to signature score
#'
#' @param mutation_matrix mutation matrix with sample name in the row and genes in the column
#' @param signature_matrix signature data frame with identifier and target signatures
#' @param id_signature_matrix column name of identifier
#' @param signature name of target signature
#' @param min_mut_freq minimum frequency of mutations
#' @param plot logical variable, if TRUE, plot will be save in the `save_path`
#' @param method multi or Wilcoxon test only, if `multi` is applied, both `cuzick test` and `wilcoxon` will be performed
#' @param save_path path to save plot and statistical analyses
#' @param palette palette of box plot
#' @param show_plot logical variable, if TRUE, plot will be printed.
#' @param show_col show code of palette
#' @param width width of oncoprint
#' @param height height of oncoprint
#' @param oncoprint_group_by signature must be group by mean or quantile
#' @param oncoprint_col color of mutation
#' @param jitter if true, each point will be drawn in the box plot with jitter
#' @param gene_counts define the number of genes which will be shown in the oncoprint
#'
#' @author Dongqiang Zeng
#' @return
#' @export
#'
#' @examples
find_mutations<-function(mutation_matrix, signature_matrix, id_signature_matrix = "ID", signature,min_mut_freq = 0.05,plot = TRUE, method = "multi", save_path = NULL,palette = "paired3",show_plot = TRUE,show_col = FALSE,width = 8, height = 4,oncoprint_group_by = "mean",oncoprint_col = "#224444",gene_counts = 10,jitter = FALSE){



  if(is.null(save_path)){
    file_name<-paste0(signature,"-relevant-mutations")
  }else{
    file_name<-save_path
  }

  if ( ! file.exists(file_name) )
    dir.create(file_name)
  abspath<-paste0(getwd(),"/",file_name,"/" )
  #######################################################

  if(max(mutation_matrix)>4){
    mutation_matrix[mutation_matrix>=3&mutation_matrix<=5]<-3
    mutation_matrix[mutation_matrix>5]<-4
  }

  mut2<-mutation_matrix
  mut2[mut2>=1]<-1

  mut_onco<-mut2

  mutfreq<-data.frame(head(sort(colSums(mut2),decreasing = T),500))
  colnames(mutfreq)<-"Freq"
  index<-which(mutfreq$Freq>=dim(mut2)[1]*min_mut_freq)
  index<-max(index)
  input_genes<-names(head(sort(colSums(mut2),decreasing = T),index))
  input_genes<-unique(input_genes)
  input_genes<-input_genes[!is.na(input_genes)]

  mutation_matrix<-mutation_matrix[,colnames(mutation_matrix)%in%input_genes]
  ########################################################

  colnames(signature_matrix)[which(colnames(signature_matrix)==id_signature_matrix)]<-"ID"

  mutation_matrix<-as.data.frame(mutation_matrix)
  mutation_matrix<-tibble:: rownames_to_column(mutation_matrix,var = "ID")


  sig_mut<-merge(signature_matrix,mutation_matrix,by = "ID",all = F)
  sig_mut<-tibble:: column_to_rownames(sig_mut,var = "ID")


  mytheme<-theme_light()+
    theme(
      plot.title=element_text(size=rel(2.8),hjust=0.5),
      axis.title.y=element_text(size=rel(2.5)),
      axis.title.x= element_blank(),
      axis.text.x= element_text(face="plain",size=30,angle=0,color="black"),#family="Times New Roman"
      axis.text.y = element_text(face="plain",size=20,angle=90,color="black"),#family="Times New Roman"
      axis.line=element_line(color="black",size=0.70))+theme(
        legend.key.size=unit(.3,"inches"),
        legend.title=element_blank(),
        legend.position="none",
        legend.direction="horizontal",
        legend.justification=c(.5,.5),
        legend.box="vertical",
        legend.box.just="top",
        legend.text=element_text(colour="black",size=10,face = "plain")
      )


  if(method == "multi"){


    input<-sig_mut[,c(signature,input_genes)]

    ##############################
    aa<-lapply(input[,input_genes], function(x) PMCMRplus::cuzickTest(input[,1]~x))
    res1<-data.frame(p.value = sapply(aa, getElement, name = "p.value"),
                    names=input_genes,
                    statistic = sapply(aa, getElement, name = "statistic"))
    res1$adjust_pvalue<-p.adjust(res1$p.value,method = "BH",n=length(res1$p.value))
    print(">>>> Result of Cuzick Test")
    res1<-res1[order(res1$p.value,decreasing = F),]
    print(res1[1:10,])

    write.csv(res1,paste0(abspath,"1-cuzickTest-test-relevant-mutations.csv"))


    if(plot){
      ####################################
      top10_genes<-res1$names[1:10]
      top10_genes<- top10_genes[!is.na(top10_genes)]
      top10_genes<-as.character(top10_genes[top10_genes%in%colnames(input)])
      input_long<-input[,c(signature,top10_genes)]
      input_long<-reshape2:: melt(input_long,id.vars = 1,
                          variable.name = "Gene",
                          value.name = "mutation")
      input_long[,signature]<-as.numeric(input_long[,signature])
      input_long$mutation<-as.factor(input_long$mutation)
      ####################################

      pl<-list()
      for(i in 1:length(top10_genes)){
        gene<- top10_genes[i]
        dd<-input_long[input_long$Gene==gene,]
        pl[[i]]<-ggplot(dd, aes(x=mutation, y = !!sym(signature), fill=mutation)) +
          geom_boxplot(outlier.shape = NA,outlier.size = -0.5)+
          # geom_jitter(width = 0.25,size= 5.9,alpha=0.75,color ="black")+
          scale_fill_manual(values = palettes(category = "box",palette = palette,show_col = show_col))+
          mytheme+theme(legend.position="none")+
          ggtitle(paste0(top10_genes[i]))+
          mytheme+stat_compare_means(comparisons = combn(as.character(unique(dd[,"mutation"])), 2, simplify=F),size=6)+
          stat_compare_means(size=6)

        if(jitter){
          pl[[i]]<-pl[[i]]+geom_jitter(width = 0.25,size= 5.9,alpha=0.75,color ="black")
        }
        ggsave(pl[[i]],filename = paste0(4+i,"-1-",gene,"-continue.pdf"),
               width = 4.2,height = 6.5,path = file_name)
      }
      com_plot<- cowplot::plot_grid(pl[[1]],pl[[2]],pl[[3]],pl[[4]],pl[[5]],pl[[6]],pl[[7]],pl[[8]],pl[[9]],pl[[10]],
                      labels = "AUTO",ncol = 5,nrow = 2,label_size = 36)
      if(show_plot) print(com_plot)
      #####################################
      ggsave(com_plot,filename = "3-Relevant_mutations_Continue.pdf",width = 25,height = 17,path = file_name)
      #####################################
    }

    sig_mut2<- rownames_to_column(sig_mut,var = "ID")

    patr1<-sig_mut2[,c("ID",signature)]
    part2<-sig_mut2[,input_genes]
    part2[part2>=1]<-1
    sig_mut2<-cbind(patr1,part2)
    sig_mut2<-column_to_rownames(sig_mut2,var = "ID")

    input2<-sig_mut2

    aa<-lapply(input2[,input_genes], function(x) wilcox.test(input2[,1]~x))

    res2<-data.frame(p.value = sapply(aa, getElement, name = "p.value"),
                    names = input_genes,
                    statistic = sapply(aa, getElement, name = "statistic"))

    res2$adjust_pvalue<-p.adjust(res2$p.value,method = "BH",n=length(res2$p.value))

    res2<-res2[order(res2$p.value,decreasing = F),]
    print(">>>> Result of Wilcoxon test")
    print(res2[1:10,])
    write.csv(res2, paste0(abspath,"2-Wilcoxon-test-relevant-mutations.csv"))

    result<-list("cuzick_test" = res1, "wilcoxon_test" = res2,
                 'sig_mut_data1' = input, "sig_mut_data2" = input2)


    if(plot){

      ####################################
      top10_genes<-res2$names[1:10]
      top10_genes<- top10_genes[!is.na(top10_genes)]
      top10_genes<-as.character(top10_genes[top10_genes%in%colnames(input2)])

      input_long<-input2[,c(signature,top10_genes)]
      input_long<-reshape2:: melt(input_long,id.vars = 1,
                          variable.name = "Gene",
                          value.name = "mutation")
      input_long[,signature]<-as.numeric(input_long[,signature])
      input_long$mutation<-as.factor(input_long$mutation)

      input_long$mutation<-ifelse(input_long$mutation==0,"WT","Mutated")
      ####################################

      pl<-list()
      for(i in 1:length(top10_genes)){
        gene<- top10_genes[i]
        dd<-input_long[input_long$Gene==gene,]
        pl[[i]]<-ggplot(dd, aes(x=mutation, y = !!sym(signature), fill=mutation)) +
          geom_boxplot(outlier.shape = NA,outlier.size = -0.5)+
          # geom_jitter(width = 0.25,size=5.5,alpha=0.75,color ="black")+
          scale_fill_manual(values= palettes(category = "box",palette = palette,show_col = show_col))+
          mytheme+
          theme(legend.position="none")+
          ggtitle(paste0(top10_genes[i]))+
          mytheme+
          stat_compare_means(comparisons = combn(as.character(unique(dd[,"mutation"])), 2, simplify=F),size=6)
        if(jitter){
          pl[[i]]<-pl[[i]]+geom_jitter(width = 0.25,size=5.5,alpha=0.75,color ="black")
        }

        ggsave(pl[[i]],filename = paste0(4+i,"-2-",gene,"-binary.pdf"),
               width = 4.2,height = 6.5,path = file_name)
      }
      com_plot<-cowplot:: plot_grid(pl[[1]],pl[[2]],pl[[3]],pl[[4]],pl[[5]],pl[[6]],pl[[7]],pl[[8]],pl[[9]],pl[[10]],
                          labels = "AUTO",ncol = 5,nrow = 2,label_size = 36)
      if(show_plot) print(com_plot)
      #####################################
      ggsave(com_plot,filename = "4-Relevant_mutations_binary.pdf",width = 22,height = 17,path = file_name)
      #####################################
    }


  }else{
    ################################
    sig_mut2<- rownames_to_column(sig_mut,var = "ID")
    patr1<-sig_mut2[,c("ID",signature)]
    part2<-sig_mut2[,input_genes]
    part2[part2>=1]<-1
    sig_mut2<-cbind(patr1,part2)
    sig_mut2<-column_to_rownames(sig_mut2,var = "ID")
    input2<-sig_mut2
    ##############################
    aa<-lapply(input2[,input_genes], function(x) wilcox.test(input2[,1]~x))

    res<-data.frame(p.value = sapply(aa, getElement, name = "p.value"),
                     names=input_genes,
                     statistic = sapply(aa, getElement, name = "statistic"))

    res$adjust_pvalue<-p.adjust(res$p.value,method = "BH",n=length(res$p.value))

    res<-res[order(res$p.value,decreasing = F),]
    print(">>>> Result of Wilcoxon test (top 10): ")
    print(res[1:10,])

    write.csv(res, paste0(abspath,"0-Wilcoxon-test-relevant-mutations.csv"))

    result<-list("wilcoxon_test" = res,"sig_mut_data" = input2)
    #################################

    if(plot){

      ####################################
      top10_genes<-res$names[1:10]
      top10_genes<- top10_genes[!is.na(top10_genes)]
      top10_genes<-as.character(top10_genes[top10_genes%in%colnames(input2)])

      input_long<-input2[, c(signature,top10_genes)]
      input_long<-reshape2:: melt(input_long,
                                  id.vars = 1,
                                  variable.name = "Gene",
                                  value.name = "mutation")
      input_long[,signature]<-as.numeric(input_long[,signature])
      input_long$mutation<-as.factor(input_long$mutation)

      input_long$mutation<-ifelse(input_long$mutation==0,"WT","Mutated")
      ####################################
      pl<-list()
      for(i in 1:length(top10_genes)){
        gene<- top10_genes[i]
        dd<-input_long[input_long$Gene==gene,]
        pl[[i]]<-ggplot(dd, aes(x=mutation, y = !!sym(signature), fill=mutation)) +
          geom_boxplot(outlier.shape = NA,outlier.size = NA)+
          geom_jitter(width = 0.25,size=5.5,alpha=0.75,color ="black")+
          scale_fill_manual(values= palettes(category = "box",palette = palette,show_col = show_col))+
          mytheme+theme(legend.position="none")+
          ggtitle(paste0(top10_genes[i]))+
          mytheme+
          stat_compare_means(comparisons = combn(as.character(unique(dd[,"mutation"])), 2, simplify=F),size=6)

        ggsave(pl[[i]],filename = paste0(i,"-1-",gene,"-binary.pdf"),
               width = 4.2,height = 6.5,path = file_name)
      }
      com_plot<-cowplot:: plot_grid(pl[[1]],pl[[2]],pl[[3]],pl[[4]],pl[[5]],pl[[6]],pl[[7]],pl[[8]],pl[[9]],pl[[10]],
                          labels = "AUTO",ncol = 5,nrow = 2,label_size = 36)
      if(show_plot) print(com_plot)
      #####################################
      ggsave(com_plot,filename = "0-Relevant_mutations_binary.pdf",width = 22,height = 17,path = file_name)
      #####################################
    }


  }


  genes<-result$wilcoxon_test$names
  genes<-genes[1:gene_counts]
  signature_matrix<-signature_matrix[!duplicated(signature_matrix$ID),]
  signature_matrix<-signature_matrix[signature_matrix$ID%in%rownames(mut_onco),]
  mut_onco<-mut_onco[rownames(mut_onco)%in%signature_matrix$ID,]
  ####################################

  pdata_group<- signature_matrix[,c("ID",signature)]
  pdata_group[,signature]<-as.numeric(pdata_group[,signature])

  max_sig<-max(pdata_group[,signature],na.rm =  TRUE )
  min_sig<-min(pdata_group[,signature],na.rm =  TRUE)
  #################################
  if(oncoprint_group_by=="mean"){
    if(!"group2"%in%colnames(pdata_group)){
      pdata_group$group<-ifelse(pdata_group[,signature]>=mean(pdata_group[,signature]),"High","Low")
    }
  }else if(oncoprint_group_by=="quantile3"){
    if(!"group3"%in%colnames(pdata_group)){
      q1<-quantile(pdata_group[,signature],probs = 1/3)
      q2<-quantile(pdata_group[,signature],probs = 2/3)
      pdata_group$group<-ifelse(pdata_group[,signature]<=q1,"Low",ifelse(pdata_group[,signature]>=q2,"High","Middle"))
    }
  }else{
    stop("Signature must be group by mean or quantile3 \n")
  }
  print(head(pdata_group))
  idh<-pdata_group[pdata_group$group=="High","ID"]
  idl<-pdata_group[pdata_group$group=="Low","ID"]
  pdata1<-pdata_group[pdata_group$ID%in%idh, ]
  pdata2<-pdata_group[pdata_group$ID%in%idl, ]


  # library(ComplexHeatmap)
  group_col<-palettes(category = "box",palette = palette,show_col = show_col)

  h1<-ComplexHeatmap:: HeatmapAnnotation(Signature_score = anno_barplot(as.numeric(pdata1[,signature]),
                                                        border=FALSE,
                                                        gp = gpar(fill="#2D004B"),
                                                        axis = TRUE,
                                                        ylim = c(min_sig,max_sig)),

                         Group = pdata1$group,
                         annotation_height=unit.c(rep(unit(1.5, "cm"), 1), rep(unit(0.5, "cm"), 1)), #unit.c(rep(unit(0.9, "cm"), 5))
                         annotation_legend_param=list(labels_gp = gpar(fontsize = 10),
                                                      title_gp = gpar(fontsize = 10, fontface = "bold"),
                                                      ncol=1),
                         gap=unit(c(2,2), "mm"),
                         col=list(Group = c("High" = group_col[1],"Low" = group_col[2])),
                         show_annotation_name = TRUE,
                         #annotation_name_side="left",
                         annotation_name_gp = gpar(fontsize = 12))

  h2<-ComplexHeatmap:: HeatmapAnnotation(Signature_score = anno_barplot(as.numeric(pdata2[,signature]),
                                                        border=FALSE,
                                                        gp = gpar(fill="#2D004B"),
                                                        axis = TRUE,
                                                        ylim = c(min_sig,max_sig)),

                         Group = pdata2$group,
                         annotation_height=unit.c(rep(unit(1.5, "cm"), 1), rep(unit(0.5, "cm"), 1)), #unit.c(rep(unit(0.9, "cm"), 5))
                         annotation_legend_param=list(labels_gp = gpar(fontsize = 10),
                                                      title_gp = gpar(fontsize = 10, fontface = "bold"),
                                                      ncol=1),
                         gap=unit(c(2,2), "mm"),
                         col=list(Group = c("High" = group_col[1],"Low" = group_col[2])),
                         show_annotation_name = TRUE,
                         #annotation_name_side="left",
                         annotation_name_gp = gpar(fontsize = 12))





  col = c(mut = oncoprint_col)
  mut1<-t(mut_onco[rownames(mut_onco)%in%idh, colnames(mut_onco)%in%genes])
  mut2<-t(mut_onco[rownames(mut_onco)%in%idl, colnames(mut_onco)%in%genes])

  mut1<-list(mut = mut1)
  mut2<-list(mut = mut2)
  #########################################
  ho1<-ComplexHeatmap:: oncoPrint(mut1,
                 alter_fun_is_vectorized = FALSE,
                 alter_fun = list(mut = function(x, y, w, h) grid.rect(x, y, w*0.9, h*0.88,
                                                                       gp = gpar(fill = oncoprint_col, col = oncoprint_col))),
                 column_title = paste0(" High ", signature),
                 show_heatmap_legend = FALSE,
                 heatmap_legend_param = list(title = "", labels = ""),
                 col = col,
                 top_annotation = h1)


  ho2<-ComplexHeatmap:: oncoPrint(mut2,
                 alter_fun_is_vectorized = FALSE,
                 alter_fun = list(mut = function(x, y, w, h) grid.rect(x, y, w*0.9, h*0.88,
                                                                       gp = gpar(fill = oncoprint_col, col = oncoprint_col))),
                 column_title = paste0(" Low ", signature),
                 show_heatmap_legend = FALSE,
                 heatmap_legend_param = list(title = "", labels = "Mutation"),
                 col = col,
                 top_annotation = h2)


  p<-ho1+ho2

  # fig.path<-paste0(getwd(),"/",save_path)
  # save to pdf
  pdf(file.path(abspath, paste0("0-OncoPrint-",signature,".pdf")), width = width, height = height)
  draw(p)
  invisible(dev.off())
  # print to screen
  # draw(p)
  if(show_plot){
    print(p)
  }

  return(result)

}
